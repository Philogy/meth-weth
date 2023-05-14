import subprocess
import sys
import os


def main():
    macro = sys.argv[1]
    with open('src/METH_WETH.huff', 'r') as f:
        contract_src = f.read()

    with open('src/__temp.huff', 'w') as f:
        f.write(
            contract_src.replace(
                f'#define macro MAIN() = takes(0) returns(0) {{',
                f'#define macro MAIN() = takes(0) returns(0) {{\n    __codesize({macro})',
            )
        )

    bytecode = bytes.fromhex(subprocess.getoutput(f'huffc -r src/__temp.huff'))
    push_len = (bytecode[0] & 0x1f) + 1
    value = int.from_bytes(bytecode[1: 1 + push_len], 'big')

    print(f'Macro size: {value} (0x{value:02x})')

    os.remove('src/__temp.huff')


if __name__ == '__main__':
    main()
