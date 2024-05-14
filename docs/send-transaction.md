# Signing & Sending transactions

This guide provides a step-by-step process on how to sign and send Ethereum transactions using the Web3.swift library and the Turnkey client.

Note: While any web3 library can be used for transaction handling, this guide specifically demonstrates the use of [Web3.swift](https://github.com/Boilertalk/Web3.swift) in conjunction with the Turnkey client.

### Prerequisites

- Ensure you have the Web3.swift library installed in your project.
- Ensure you have access to the Turnkey client and necessary credentials (API keys, organization ID, etc.).

## Step 1: Setup Web3 and Ethereum Address

First, initialize the Web3 instance with an RPC URL and set up the Ethereum address from which the transaction will be sent.
Note: For this example we're using Holesky however, the code is generalizable to other chains.

```swift
let infuraAPIKey = "<infura_api_key>"
let walletFromAddress = "<wallet_from_address>"
let web3 = Web3(rpcURL: "https://holesky.infura.io/v3/\(infuraAPIKey)")
let from = try EthereumAddress(hex: walletFromAddress, eip55: true)
```

## Step 2: Get Transaction Count (Nonce)

Fetch the current transaction count (nonce) for the address. This is necessary to prevent transaction replay attacks.

```swift
let nonce = try await web3.eth.getTransactionCount(address: from)
```

## Step 3: Build the Ethereum Transaction

Create an EthereumTransaction object with the necessary parameters such as nonce, gas fees, recipient address, and value.

```swift
let transaction = EthereumTransaction(
    nonce: nonce,
    maxFeePerGas: EthereumQuantity(quantity: 21.gwei),
    maxPriorityFeePerGas: EthereumQuantity(quantity: 1.gwei),
    gasLimit: 29000,
    to: try EthereumAddress(hex: "0xRecipientAddress", eip55: true),
    value: EthereumQuantity(quantity: 1000.gwei),
    transactionType: .eip1559
)
```

## Step 4: Serialize the Transaction

Serialize the transaction into RLP (Recursive Length Prefix) format, which is a common encoding method used in Ethereum to encode structured data.

```swift
let rlpItem: RLPItem = RLPItem.array([
    .bigUInt(EthereumQuantity(integerLiteral: 17000).quantity),
    .bigUInt(nonce.quantity),
    .bigUInt(transaction.maxPriorityFeePerGas?.quantity ?? 0),
    .bigUInt(transaction.maxFeePerGas?.quantity ?? 0),
    .bigUInt(transaction.gasLimit?.quantity ?? 0),
    .bytes(transaction.to?.rawAddress ?? Bytes()),
    .bigUInt(transaction.value?.quantity ?? 0),
    .bytes(Bytes()), // input data
    .array([]) // Access list
])

let serializedTransaction = try RLPEncoder().encode(rlpItem)
let transactionHexString = "02" + serializedTransaction.map { String(format: "%02x", $0) }.joined()
```

## Step 5: Sign the Transaction

Use the Turnkey client to sign the serialized transaction.

```swift
let client = TurnkeyClient(apiPrivateKey: "<api_private_key>", apiPublicKey: "<api_public_key>")
let response = try await client.signTransaction(
    organizationId: "<organization_id>",
    signWith: "<private_key_id>",
    unsignedTransaction: transactionHexString,
    _type: .TRANSACTION_TYPE_ETHEREUM
)
```

## Step 6: Send the Signed Transaction

Finally, send the signed transaction to the Ethereum network.

```swift
let request = BasicRPCRequest(
    id: 0,
    jsonrpc: Web3.jsonrpc,
    method: "eth_sendRawTransaction",
    params: ["0x" + signedTransaction]
)

let hash = try await web3.provider.send(request: request)
print("Transaction hash: \(hash.hex())")
```

# Conclusion

This guide outlines the steps to sign and send Ethereum transactions using Web3.swift and the Turnkey client. Adjust parameters and error handling as necessary to fit the specific needs of your application.
