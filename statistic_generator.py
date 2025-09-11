import pandas as pd
import json
import os

# === INPUT FILE ===
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_RESULTS = os.path.join(SCRIPT_DIR, "llm_property_check_results.csv")

SKELETON_JSON = "./contracts/bank/skeleton.json" # REPLACE HERE  contract_name! i.e. bank
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "statistics_results.csv")

# === READ FILE ===
df = pd.read_csv(CSV_RESULTS)

# Normalize values
df["ground_truth"] = df["ground_truth"].astype(str).str.strip().str.upper()
df["llm_answer"] = df["llm_answer"].astype(str).str.strip().str.upper()

# Load skeleton.json for mapping property_id → property_type
with open(SKELETON_JSON, "r") as f:
    skeleton = json.load(f)
property_types = skeleton.get("property-types", {})

# Add column property_type based on mapping
df["property_type"] = df["property_id"].map(property_types)

# Only consider valid answers
df_valid = df[df["llm_answer"].isin(["TRUE", "FALSE"])]

# Compute metrics
def compute_metrics(subset):
    TP = ((subset["ground_truth"] == "TRUE") & (subset["llm_answer"] == "TRUE")).sum()
    TN = ((subset["ground_truth"] == "FALSE") & (subset["llm_answer"] == "FALSE")).sum()
    FP = ((subset["ground_truth"] == "FALSE") & (subset["llm_answer"] == "TRUE")).sum()
    FN = ((subset["ground_truth"] == "TRUE") & (subset["llm_answer"] == "FALSE")).sum()
    total = TP + TN + FP + FN

    accuracy = (TP + TN) / total * 100 if total > 0 else 0
    precision_raw = TP / (TP + FP) if (TP+FP) > 0 else 0
    recall_raw = TP / (TP + FN) if (TP+FN) > 0 else 0
    specificity = TN / (TN + FP) * 100 if (TN+FP) > 0 else 0
    f1 = 2 * (precision_raw * recall_raw) / (precision_raw + recall_raw) if (precision_raw + recall_raw) > 0 else 0

    return {
        "TP": TP,
        "TN": TN,
        "FP": FP,
        "FN": FN,
        "Accuracy (%)": round(accuracy, 2),
        "Precision (%)": round(precision_raw * 100, 2),
        "Recall (%)": round(recall_raw * 100, 2),
        "Specificity (%)": round(specificity, 2),
        "F1 Score": round(f1, 4),
    }

# === Metrics for each property type ===
results = []
for ptype, subset in df_valid.groupby("property_type"):
    stats = compute_metrics(subset)
    stats["property_type"] = ptype
    results.append(stats)

# === Global metrics ===
global_stats = compute_metrics(df_valid)
global_stats["property_type"] = "OVERALL"
results.append(global_stats)

# === Create dataframe and save on csv ===
results_df = pd.DataFrame(results)
results_df = results_df[["property_type","TP","TN","FP","FN","Accuracy (%)","Precision (%)","Recall (%)","Specificity (%)","F1 Score"]]

results_df.to_csv(OUTPUT_FILE, index=False)
print(f"✅ Results saved in {OUTPUT_FILE}")
