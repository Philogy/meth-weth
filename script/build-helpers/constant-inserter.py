from py_huff.compile import compile
from typing import Callable
import re

METH_PATH = 'src/meth-huff/METH.huff'


def transform_file(path: str, transformation: Callable[[str], str]):
    with open(path, 'r+') as f:
        contents = f.read()
        f.seek(0)
        f.write(transformation(contents))


def main():
    out = compile(METH_PATH, {})
    runtime = out.runtime

    transform_file(
        'src/METHConstants.sol',
        lambda constants: re.sub(
            r'(bytes constant METH_RUNTIME =\n    hex")(?:[A-Fa-f0-9]+)(";)',
            lambda m: f'{m.group(1)}{runtime.hex()}{m.group(2)}',
            constants
        )
    )


if __name__ == '__main__':
    main()
