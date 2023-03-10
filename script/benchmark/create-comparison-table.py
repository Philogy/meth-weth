import re
from collections import namedtuple
import os


with open(os.path.join(*os.path.split(__file__)[:-1], 'out.txt'), 'r') as f:
    input_gas_use = f.read()


Table = namedtuple('Table', ['name', 'description', 'header', 'fixed_values'])

tables = [
    Table(
        'Direct Calls',
        'This table contains a comparison of gas costs for limited function calls.',
        ['Action', 'WETH9', 'METH', 'Difference', 'Added Details'],
        [
            ('`deposit()`', 'Wrap non-zero amount with no existing balance'),
            ('`transfer(...)`', 'Transfer to account with zero balance'),
            ('receive-fallback', 'Wrap non-zero amount with no existing balance'),
            (
                '`approve(...)`',
                'Grant infinite allowance (requires truncating calldata for METH)'
            ),
            ('`withdraw(...)`', 'Unwrap specific amount'),
            (
                '`transferFrom(...)`',
                'Transfer from non-zero to non-zero with infinite approval'
            ),
            (None, None),
            (
                '`transferFrom(...)`',
                'Transfer from non-zero to non-zero with finite approval'
            ),
            (
                'withdraw all remaining balance',
                'Unwrap all remaining (`withdraw(uint)` in WETH, `withdrawAll()` in METH)'
            )
        ]
    )

]


def main():
    inp = input_gas_use.strip()
    gas_uses = [
        int(m.group(1))
        for m in re.finditer(r'Paid: \d+\.\d+ ETH \((\d+) gas \* \d+\.\d+ gwei\)', inp)
    ]
    assert len(gas_uses) % 2 == 0, 'Must have even amount of gas outputs'
    table_i = 0
    i = 0
    table_rows = []
    for weth_use, meth_use in [*zip(
        gas_uses[:len(gas_uses) // 2],
        gas_uses[len(gas_uses) // 2:]
    ), (None, None)]:
        table = tables[table_i]
        if i >= len(table.fixed_values):
            print(f'### {table.name}')
            table_head = '|'.join(table.header)
            print(table.description)
            print()
            head_str = f'|{table_head}|'
            print(head_str)
            print(''.join('-|'[c == '|'] for c in head_str))
            for first, weth_use, meth_use, last in table_rows:
                print(
                    f'|{first}|{weth_use:,}|{meth_use:,}|{meth_use - weth_use:,}|{last}|'
                )
            print()

            table_i += 1
            i = 0
            table_rows = []

            continue

        first_col, last_col = table.fixed_values[i]
        i += 1
        if first_col is None and last_col is None:
            continue

        table_rows.append(
            (first_col, weth_use, meth_use, last_col)
        )


if __name__ == '__main__':
    main()
