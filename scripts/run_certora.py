"""
Name: run_certora
Description:
    Operates on either a single file or every file within a directory.

Usage:
    python run_certora.py -c <file_or_dir> -s <spec_file> -o <output_dir>
"""

from string import Template
from multiprocessing import Pool
import subprocess
import argparse
import utils
import glob
import sys
import os
import re

THREADS = 6     # n of parallel executions

COMMAND_TEMPLATE = Template(
    'certoraRun $contract_path:$name --verify $name:$spec_path --wait_for_results'
)


# Check if there is an error in the output (Deprec)
def has_property_error(output, property):
    pattern = rf'.*ERROR: \[rule\] {re.escape(property).upper()}.*'
    return re.search(pattern, output, re.DOTALL)


def no_errors_found(output):
    pattern = r'.*No errors found by Prover!.*'
    return re.search(pattern, output, re.DOTALL)


def has_critical_error(output):
    pattern = r'.*CRITICAL.*'
    return re.search(pattern, output, re.DOTALL)


def get_properties(spec_path):
    """
    Retrieves the list of properties defined in CVL spec files.

    Returns:
        list: The list of property names.
    """
    return (
            glob.glob(f'{spec_path}/*.spec')
            if os.path.isdir(spec_path)
            else [spec_path]
    )


def run_certora(contract_path, spec_path):
    """
    Runs a single certora experiment.

    Returns:
        tuple: (outcome, log)
    """

    contract_name = utils.get_contract_name(contract_path)

    if not os.path.isfile(contract_path): 
        print("[ERROR]: " + contract_path + " not found", 
              file=sys.stderr)
        sys.exit(1)

    if not contract_name:
        print("[ERROR]: Could not retrieve contract name: " + contract_path , 
              file=sys.stderr)
        sys.exit(1)

    params = {}
    params['contract_path'] = contract_path
    params['name'] = contract_name
    params['spec_path'] = spec_path

    command = COMMAND_TEMPLATE.substitute(params)
    print(command)
    log = subprocess.run(command.split(), capture_output=True, text=True)

    if log.stderr:
        print(log.stderr, file=sys.stderr)

    if has_critical_error(log.stdout):
        print(log.stdout, file=sys.stderr)
        sys.exit(1)

    if no_errors_found(log.stdout):
        print(contract_path + ", " + spec_path + ": " + utils.STRONG_POSITIVE)
        return (utils.STRONG_POSITIVE, log.stdout+"\n"+log.stderr)
    else:
        print(contract_path + ", " + spec_path + ": " + utils.STRONG_NEGATIVE)
        return (utils.STRONG_NEGATIVE, log.stdout+"\n"+log.stderr)


def run_certora_parallel(id, contract_path, spec_path, logs_dir):
    """
    Calls run_certora() and writes the log.
    """
    (outcome, log) = run_certora(contract_path, spec_path)
    utils.write_log(logs_dir + id + '.log', log)
    return (id, outcome)


def run_all_certora(contracts_dir, spec_path, logs_dir):
    """
    Runs certora on all files of a directory.

    Args:
        contracts_dir (str): Contracts directory path.
        spec_path (str): CVL spec dir path.
        log_dir (str): Log directory path.

    Returns:
        dict: {key_v*: outcome}
    """
    outcomes = {}

    specs = get_properties(spec_path)   # list of paths

    # Specific properties
    bound_properties_paths = list(filter(
            lambda x: re.search(".*_v.*", x),
            specs))
    unbound_properties_paths = list(
            set(specs) - set(bound_properties_paths))

    inputs = []     # inputs for run_certora_parallel()

    for v_path in os.listdir(contracts_dir):
        if not os.path.isdir(contracts_dir + v_path):     # lib/ is ignored

            # Extract base id from base path (e.g. v1)
            v_id = v_path.split('/')[-1].split('_')[-1].split('.')[0]

            v_bound = list(filter(
                    lambda x: re.search(f'.*_{v_id}.*', x),
                    bound_properties_paths))

            v_unbound = unbound_properties_paths

            for bp_path in v_bound:
                p_id = bp_path.split('/')[-1].split('_')[0]     # ../p1_v1.sol -> p1
                # Remove bound properties from the unbound variants
                v_unbound = list(filter(
                        lambda x: not re.search(f'{p_id}', x),
                        v_unbound
                        ))

            v_properties_paths = v_bound + v_unbound

            for s_path in v_properties_paths:
                id = (  # e.g. p1_v1
                        s_path.split('.')[-2].split('/')[-1].split('_')[0] +
                        '_' +
                        v_path.split('_')[-1].split('.sol')[0]
                )
                inputs.append((id, contracts_dir + v_path, s_path, logs_dir))

    with Pool(processes=THREADS) as pool:
        # [(id, outcome), ...]
        results = pool.starmap(run_certora_parallel, inputs)
        for (id, outcome) in results:
            outcomes[id] = outcome

    return outcomes


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
            '--contracts',
            '-c',
            help='Contracts directory',
            required=True
            )
    parser.add_argument(
            '--specs',
            '-s',
            help='CVL Specification dir or file.',
            required=True
            )
    parser.add_argument(  # build/
            '--output',
            '-o',
            help='Output directory.',
            required=True
    )
    args = parser.parse_args()

    contracts_dir = (
            args.contracts
            if args.contracts[-1] == '/'
            else args.contracts + '/'
            )
    output_dir = args.output if args.output[-1] == '/' else args.output + '/'
    logs_dir = output_dir + 'logs/'
    spec_path = args.specs if args.specs[-1] == '/' else args.specs + '/'

    outcomes = run_all_certora(contracts_dir, spec_path, logs_dir)

    out_csv = [utils.OUT_HEADER]

    for id in outcomes.keys():
        p = id.split('_')[0]
        v = id.split('_')[1]
        out_csv.append([p, v, outcomes[id]])

    utils.write_csv(output_dir + 'out.csv', out_csv)
