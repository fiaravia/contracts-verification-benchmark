#!/usr/bin/env python3
import argparse
import os
import sys
import json
import openai
import re
import datetime 
import random
random.seed(42)
import time

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # root del progetto
SCRIPTS_DIR = os.path.join(BASE_DIR, "scripts")
CONTRACTS_DIR = os.path.join(BASE_DIR, "contracts")
API_KEY_FILE = os.path.join(SCRIPTS_DIR, "openai_api_key.txt")


def load_api_key(path=API_KEY_FILE):
    if not os.path.exists(path):
        print(f"Errore: il file {path} non esiste.", file=sys.stderr)
        sys.exit(1)
    with open(path, "r", encoding="utf-8") as f:
        return f.read().strip()


def list_properties(contract_path):
    skeleton_path = os.path.join(contract_path, "skeleton.json")
    if not os.path.exists(skeleton_path):
        print(f"Errore: {skeleton_path} non trovato.", file=sys.stderr)
        sys.exit(1)

    with open(skeleton_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    return sorted(list(data.get("properties", {}).keys()))

def get_ground_truths(contract_path):
    truth_path = os.path.join(contract_path, "ground-truth.csv")
    if not os.path.exists(truth_path):
        print(f"Error: {truth_path} not found.", file=sys.stderr)
        sys.exit(1)

    with open(truth_path, "r", encoding="utf-8") as f:
        ground_truths = {}
        for line in f:
            parts = line.strip().split(',')
            if parts[2] in ["0", "1"]:
                ground_truths[(parts[0],parts[1].replace("v",""))] = True if parts[2] == "1" else False
    return ground_truths

def choose_verification_tasks(prop, versions, ground_truths, no_sample=False):
    if no_sample:
        return [(prop, v) for v in versions]
    else:
        versions_positive = []
        versions_negative = []

        for version in versions:
            if ground_truths[(prop,version)]:
                versions_positive.append(version)
            else:
                versions_negative.append(version)
            
        k = min(len(versions_positive),len(versions_negative))

        print(f"{k=}")
        sampled_versions_positive = random.sample(versions_positive, k)
        sampled_versions_negative = random.sample(versions_negative, k)
        print(f"{sampled_versions_positive=}")
        print(f"{sampled_versions_negative=}")
        verification_tasks = [(prop, v) for v in sampled_versions_positive + sampled_versions_negative]
        print(f"{verification_tasks=}")
        return verification_tasks

def get_verification_tasks_from_csv(filepath,):
    verification_tasks = []
    if not os.path.exists(filepath):
        print(f"Error: the file {filepath} does not exist.", file=sys.stderr)
        sys.exit(1)
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split(',')
            if len(parts) == 2:
                verification_tasks.append((parts[0], parts[1]))
            else:
                print(f"Warning: malformed line in {filepath}: {line}", file=sys.stderr)
    return verification_tasks

def save_verification_tasks(verification_tasks, filepath):
    with open(filepath, "a", encoding="utf-8") as f:
        for prop, version in verification_tasks:
            f.write(f"{prop},{version}\n")

def list_versions(versions_path):
    if not os.path.exists(versions_path):
        return []
    versions = []
    for fname in os.listdir(versions_path):
        if fname.endswith(".sol"):
            # estrae "v1", "v2" ecc.
            base = fname.replace(".sol", "")
            parts = base.split("_v")
            if len(parts) == 2:
                versions.append(parts[1])
    return sorted(versions, key=lambda x: int(re.sub(r'\D', '', x) or 0))



def load_contract_code(contract, version):
    version_folder = os.path.join(CONTRACTS_DIR, contract, "versions")

    # Normalizziamo il target da cercare
    target = f"{normalize_name(contract)}v{normalize_name(version)}"

    # Cerchiamo tra i file .sol quello che matcha
    for fname in os.listdir(version_folder):
        if fname.endswith(".sol"):
            candidate = normalize_name(fname.replace(".sol", ""))
            if candidate == target:
                filepath = os.path.join(version_folder, fname)
                break
    else:
        print(f"Errore: nessun file solidity trovato per {contract} v{version} in {version_folder}", file=sys.stderr)
        sys.exit(1)

    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Rimuove tutte le righe che iniziano con "/// @custom:"
    cleaned_lines = [line for line in lines if not line.strip().startswith("/// @custom:")]
    return "".join(cleaned_lines)



def load_property_description(contract, property_name):
    skeleton_path = os.path.join(CONTRACTS_DIR, contract, "skeleton.json")
    if not os.path.exists(skeleton_path):
        print(f"Errore: {skeleton_path} non trovato.", file=sys.stderr)
        sys.exit(1)

    with open(skeleton_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    props = data.get("properties", {})
    if property_name not in props:
        print(f"Errore: proprietà {property_name} non trovata in {skeleton_path}.", file=sys.stderr)
        sys.exit(1)

    return props[property_name]


def run_experiment(contract, prop, version, prompt_file, token_limit, model):
    # Carica prompt
    prompt_path = os.path.join(SCRIPTS_DIR, prompt_file)
    if not os.path.exists(prompt_path):
        print(f"Errore: prompt file {prompt_path} non trovato.", file=sys.stderr)
        sys.exit(1)
    with open(prompt_path, "r", encoding="utf-8") as f:
        prompt_template = f.read()

    # Carica codice Solidity e descrizione proprietà
    code = load_contract_code(contract, version)
    property_desc = load_property_description(contract, prop)

    # Sostituisci placeholders
    prompt_text = prompt_template.replace("{code}", code).replace("{property_desc}", property_desc)

    #with open(f"logs_prompt/prompt{str(datetime.datetime.now())}.txt", "w", encoding="utf-8") as f:
    #    f.write(prompt_text)

    # Inizializza client OpenAI
    client = openai.OpenAI(api_key=load_api_key())

    try:
        if model.startswith("gpt-4o") or model.startswith("gpt-3.5"):
            # Modelli chat classici
            response = client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt_text}],
                max_tokens=token_limit or 500
            )
            output_text = response.choices[0].message.content
        else:
            # Modelli nuovi (gpt-5, gpt-4.1, ecc.)
            response = client.responses.create(
                model=model,
                input=[{"role": "user", "content": prompt_text}],
                max_output_tokens=token_limit or 500
            )
            output_text = response.output_text

        print(f"=== {contract} / {prop} / v{version} ===")
        print(output_text)
        print("\n")

    except Exception as e:
        print(f"Errore durante la chiamata API: {e}", file=sys.stderr)
        sys.exit(1)


def normalize_name(name: str) -> str:
    """Rende il nome uniforme: minuscolo, senza caratteri speciali."""
    return re.sub(r'[^a-z0-9]', '', name.lower())

def find_contract_folder(contract_arg: str) -> str:
    """Trova la cartella giusta in base al nome normalizzato."""
    target = normalize_name(contract_arg)
    for folder in os.listdir(CONTRACTS_DIR):
        if os.path.isdir(os.path.join(CONTRACTS_DIR, folder)):
            if normalize_name(folder) == target:
                return folder
    print(f"Errore: nessuna cartella trovata per '{contract_arg}' in {CONTRACTS_DIR}", file=sys.stderr)
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Run ChatGPT experiments on benchmark.")
    parser.add_argument("--contract", required=True, help="Nome del contratto (cartella in contracts/)")
    parser.add_argument("--property", help="Nome della proprietà (opzionale)")
    parser.add_argument("--version", help="Numero versione (opzionale)")
    parser.add_argument("--prompt", required=True, help="File del prompt (deve stare in scripts/)")
    parser.add_argument("--tokens", type=int, default=500, help="Token limit opzionale")
    parser.add_argument("--model", default="gpt-4", help="Modello da usare (default gpt-4)")
    parser.add_argument("--no_sample", action='store_true', required=False, default=False, help="Disable verification tasks sampling. ")
    parser.add_argument("--use_csv_verification_tasks", required=False, default=False, help="Use verification tasks from a CSV file. ")

    args = parser.parse_args()

    # Trova la cartella del contratto ignorando maiuscole/minuscole e special chars
    contract_folder = find_contract_folder(args.contract)

    base_path = os.path.join(CONTRACTS_DIR, contract_folder)

    # Se manca property → tutte
    properties = [args.property] if args.property else list_properties(base_path)
    if not properties:
        print(f"Nessuna proprietà trovata in {base_path}", file=sys.stderr)
        sys.exit(1)

    versions_path = os.path.join(base_path, "versions")

    ground_truths = get_ground_truths(base_path)

    verification_tasks = []
    
    for prop in properties:
        # Se manca version → tutte
        versions = [args.version] if args.version else list_versions(versions_path)
        if not versions:
            print(f"Nessuna versione trovata in {versions_path}", file=sys.stderr)
            sys.exit(1)

        if not args.use_csv_verification_tasks:
            verification_tasks_prop = choose_verification_tasks(prop, versions, ground_truths, args.no_sample)
            verification_tasks.extend(verification_tasks_prop)  

    if args.use_csv_verification_tasks:
        verification_tasks = get_verification_tasks_from_csv(args.use_csv_verification_tasks)
    else:
        csv_ver_tasks_name = f"verification_tasks_{str(datetime.datetime.now())}.csv".replace(" ","")
        save_verification_tasks(verification_tasks, csv_ver_tasks_name)

    print(len(verification_tasks))
    #for verification_task in verification_tasks:
    #    prop, version = verification_task
    #    run_experiment(contract_folder, prop, version, args.prompt, args.tokens, args.model)
    


if __name__ == "__main__":
    main()
