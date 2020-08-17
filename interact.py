from web3 import Web3, HTTPProvider, eth
import json

w3 = Web3(HTTPProvider('http://127.0.0.1:8545'))
w3.eth.defaultAccount = w3.eth.accounts[9]
accounts = w3.eth.accounts
gas_price = 5000000000

with open("build/Contracts/BlackJack.json") as f:
    info_json = json.load(f)

abi = info_json["abi"]
bytecode = info_json["bytecode"]

BlackJack = w3.eth.contract(bytecode=bytecode, abi=abi)

tx_hash = BlackJack.constructor(w3.toWei(0.02, 'ether'), w3.toWei(0.5, 'ether')).transact()
tx_receipt = w3.eth.waitForTransactionReceipt(tx_hash)

black_jack = w3.eth.contract(address=tx_receipt.contractAddress, abi=abi)

black_jack.functions.manageFunds(0).transact({'value': w3.toWei(1, 'ether')})

w3.eth.defaultAccount = w3.eth.accounts[0]


def printState(address):
    state = black_jack.functions.getPlayerState(address).call()
    print("""
    Player: {}
    Balance: {}
    Bet: {}, Split Bet: {}
    House: {}, Ace: {}, Cards: {}
    Hand: {}, Ace: {}, Cards: {}
    Split: {}, Ace: {}, Cards: {}
    """.format(address, w3.fromWei(w3.eth.getBalance(accounts[0]), 'ether'),
               state[0], state[1],
               state[2], state[3], state[4],
               state[5], state[6], state[7],
               state[8], state[9], state[10]))
    return state


while True:
    try:
        state = printState(accounts[0])
        choice = int(input("""11.Bet 0.Stand 1.Hit 2.Hit second 3.Hit both 4.Double 5.Split\n"""))
    except ValueError as e:
        print('Enter a valid number.')
        continue
    try:
        if choice not in [11, 0, 1, 2, 3, 4, 5]:
            continue
        # Bet
        elif choice == 11:
            tx_hash = black_jack.functions.bet().transact({'value': w3.toWei(0.05, 'ether')})
        # Stand
        elif choice == 0:
            tx_hash = black_jack.functions.play(0).transact()
        # Hit first
        elif choice == 1:
            tx_hash = black_jack.functions.play(1).transact()
        # Hit second
        elif choice == 2:
            tx_hash = black_jack.functions.play(2).transact()
        # Hit both
        elif choice == 3:
            tx_hash = black_jack.functions.play(3).transact()
        # Double
        elif choice == 4:
            tx_hash = black_jack.functions.play(4).transact({'value': w3.toWei(0.05, 'ether')})
        # Split
        elif choice == 5:
            tx_hash = black_jack.functions.play(5).transact({'value': w3.toWei(0.05, 'ether')})
        receipt = w3.eth.waitForTransactionReceipt(tx_hash)
        gas_cost = receipt.gasUsed
        eth_cost = gas_cost * gas_price
        euro_cost = float(w3.fromWei(eth_cost, 'ether')) * 145.94
        print('Gas: {}\nEth: {}\n€: {}'.format(gas_cost, eth_cost, euro_cost))
    except ValueError as e:
        print(e)
