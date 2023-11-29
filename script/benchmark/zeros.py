import subprocess


def main():
    direct_out = subprocess.getoutput('huffc -r src/METH_WETH.huff')
    out = direct_out.splitlines()[-1]

    runtime_bytecode = bytes.fromhex(out)

    zeros = runtime_bytecode.count(0)

    print(f'zeros: {zeros}')
    print(f'len(runtime_bytecode): {len(runtime_bytecode)}')
    print(f'other: {len(runtime_bytecode) - zeros}')
    print(f'Share of zero-bytes: {zeros/len(runtime_bytecode):.2%}')


if __name__ == '__main__':
    main()
