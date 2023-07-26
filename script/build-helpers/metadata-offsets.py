import subprocess


def main():
    runtime_bytecode = bytes.fromhex(
        subprocess.getoutput('huffc -r src/METH_WETH.huff').splitlines()[-1]
    )

    default_name_data = bytes.fromhex(
        '000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000214d6178696d616c6c7920456666696369656e74205772617070656420457468657200000000000000000000000000000000000000000000000000000000000000'
    )
    name_offset = runtime_bytecode.find(default_name_data)

    packed_default_symbol = bytes.fromhex(
        '044d455448000000000000000000000000000000000000000000000000000000')
    symbol_offset = runtime_bytecode.find(packed_default_symbol)

    decimals_function = bytes.fromhex(
        '5b63313ce567033417613fff57601234525934f3'
    )
    decimal_fn_offset = runtime_bytecode.find(decimals_function)
    sub_code = runtime_bytecode[decimal_fn_offset:]
    decimals_offset = sub_code.find(
        bytes.fromhex('601234525934f3')) + decimal_fn_offset + 1

    print(f'hex(name_offset): {hex(name_offset)}')
    print(f'hex(symbol_offset): {hex(symbol_offset)}')
    print(f'hex(decimals_offset): {hex(decimals_offset)}')


if __name__ == '__main__':
    main()
