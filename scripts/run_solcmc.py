"""
Operates on either a single file or every file within a directory.
"""
from pathlib import Path
import argparse
import glob
import os

import utils
from tools.solcmc import run_all

DEFAULT_TIMEOUT = '10m'
DEFAULT_SOLVER = 'z3'


def main(args):
    parser = argparse.ArgumentParser()
    parser.add_argument(
            '--contracts',
            '-c',
            help='Contracts dir or contract file.',
            required=True)
    parser.add_argument(  # build/
            '--output',
            '-o',
            help='Output directory.')
    parser.add_argument(
            '--timeout',
            '-t',
            help='Timeout time.')
    parser.add_argument(
            '--solver',
            '-s',
            help='Model checker: {z3, eld}')
    parser.add_argument(
            '--version',
            '-v',
            help='Run experiments on this version only.')
    parser.add_argument(
            '--property',
            '-p',
            help='Run experiments on this property only.')
    args = parser.parse_args(args)
    contracts = Path(args.contracts)

    # Get contracts paths
    contracts_paths = (
            glob.glob(f'{contracts}/*.sol')
            if os.path.isdir(contracts)
            else [str(contracts)])

    if args.version:
        contracts_paths = [c for c in contracts_paths if f"v{args.version}.sol" in c]

    if args.property:
        contracts_paths = [c for c in contracts_paths if f"{args.property}_v" in c]
        
    # Removes auxiliary contracts (e.g. Oracle.sol in price-bet)
    contracts_paths = [c for c in contracts_paths if f"_v" in c]

    timeout = args.timeout if args.timeout else DEFAULT_TIMEOUT
    solver = args.solver if args.solver else DEFAULT_SOLVER

    if args.output:
        output_dir = Path(args.output)
        output_dir.mkdir(parents=True, exist_ok=True)
        logs_dir = output_dir.joinpath('logs/')
        logs_dir.mkdir(parents=True, exist_ok=True)

        outcomes = run_all(contracts_paths, timeout, logs_dir, solver)

        verification_tasks = []
        out_csv = [utils.OUT_HEADER]
        for id in outcomes.keys():
            p = id.split('_')[0]
            v = id.split('_')[1]
            out_csv.append([p, v, outcomes[id]])
            verification_tasks.append([p, v])

        out_csv_path = output_dir.joinpath('out.csv')
        existing_rows = utils.read_csv(out_csv_path)
        for existing_row in existing_rows:
            existing_verification_task = existing_row[:2]
            if existing_verification_task in verification_tasks:
                continue
            if existing_verification_task == ['property','version']:
                continue
            out_csv.append(existing_row)        

        utils.write_csv(out_csv_path, out_csv)

        solver_csv_path = output_dir.joinpath(f"../../../solcmc-{solver}.csv")
        utils.merge_csvs(out_csv_path, solver_csv_path)
    else:
        run_all(contracts_paths, timeout, solver=solver)

if __name__ == '__main__':
        import sys
        main(sys.argv[1:])
