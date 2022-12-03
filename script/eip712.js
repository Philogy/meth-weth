import ethers from 'ethers'
import fs from 'fs'

const TypedDataEncoder = ethers.utils._TypedDataEncoder

const Permit = [
  {
    name: 'owner',
    type: 'address'
  },
  {
    name: 'spender',
    type: 'address'
  },
  {
    name: 'value',
    type: 'uint256'
  },
  {
    name: 'nonce',
    type: 'uint256'
  },
  {
    name: 'deadline',
    type: 'uint256'
  }
]

function getDomainSeparator(addr, name, version = 1, chainid = 1) {
  console.log(
    TypedDataEncoder.hashDomain({
      name,
      version: version.toString(),
      chainId: +chainid,
      verifyingContract: addr
    })
  )
}

function getPermitHash(
  addr,
  name,
  owner,
  spender,
  value,
  nonce,
  deadline,
  version = 1,
  chainid = 1
) {
  console.log(
    TypedDataEncoder.hash(
      {
        name,
        version: version.toString(),
        chainId: chainid,
        verifyingContract: addr
      },
      { Permit },
      {
        owner,
        spender,
        value,
        nonce,
        deadline
      }
    )
  )
}

const commands = {
  ds: getDomainSeparator,
  'domain-separator': getDomainSeparator,
  permit: getPermitHash,
  'permit-hash': getPermitHash
}

async function main() {
  const [, , cmd, ...args] = process.argv
  const cmdFn = commands[cmd]
  if (cmdFn === undefined) throw new Error(`command "${cmd}" not recognized`)
  cmdFn(...args)
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err)
    process.exit(1)
  })
