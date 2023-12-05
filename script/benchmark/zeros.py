import argparse
from py_huff.compile import compile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('file', help='Path to huff file to be compiled')
    args = parser.parse_args()

    runtime_bytecode = compile(args.file, {}).runtime

    zeros = runtime_bytecode.count(0)

    print(f'zeros: {zeros}')
    print(f'len(runtime_bytecode): {len(runtime_bytecode)}')
    print(f'other: {len(runtime_bytecode) - zeros}')
    print(f'Share of zero-bytes: {zeros/len(runtime_bytecode):.2%}')


if __name__ == '__main__':
    main()
