import subprocess

GENERAL_DEPLOYER = bytes.fromhex('600b80380380913d393df3')


def main():
    runtime = bytes.fromhex(
        subprocess.getoutput('huffc -r src/METH_WETH.huff').splitlines()[-1]
    )
    print((GENERAL_DEPLOYER + runtime).hex())


if __name__ == '__main__':
    main()
