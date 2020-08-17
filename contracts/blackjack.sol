pragma solidity ^0.5.17;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./SafeMath256.sol";

contract BlackJack is Ownable {
    using SafeMath256 for uint256;

    event Debug(string _message);

    struct PlayerState {
        uint256 bet;
        uint256 splitBet;
        uint8   houseScore;
        uint8   houseAceCounter;
        uint8   houseCardCounter;
        uint8   playerScore;
        uint8   playerAceCounter;
        uint8   playerCardCounter;
        uint8   playerSplitScore;
        uint8   playerSplitAceCounter;
        uint8   playerSplitCardCounter;
    }
    mapping (address => PlayerState) internal players;
    uint256 public minimumBet;
    uint256 public maximumBet;
    uint256 internal nonce;

    constructor(uint256 _minimumBet, uint256 _maximumBet) public {
        minimumBet = _minimumBet;
        maximumBet = _maximumBet;
    }

    function bet() external payable notInGame(msg.sender) {
        require(msg.value >= minimumBet, "Bet is too low.");
        require(msg.value <= maximumBet, "Bet is too high.");

        PlayerState memory table = PlayerState(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        table.bet = msg.value;

        uint8 card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
        table.houseScore = card > 9 ? 10 : card == 1 ? 11 : card;
        table.houseCardCounter = 1;
        if (card == 1) table.houseAceCounter = 1;

        card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
        table.playerScore = card > 9 ? 10 : card == 1 ? 11 : card;
        table.playerCardCounter = 1;
        if (card == 1) table.playerAceCounter = 1;

        card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
        uint8 second_score = card > 9 ? 10 : card == 1 ? 11 : card;
        if (table.playerScore == second_score) {
            table.playerSplitScore = second_score;
            table.playerSplitCardCounter = 1;
            if (card == 1) table.playerSplitAceCounter = 1;
        } else {
            table.playerScore += second_score;
            table.playerCardCounter = 2;
            if (card == 1) table.playerAceCounter++;
        }

        if (table.playerScore == 21) {
            houseTurn(table);
        } else {
            players[msg.sender] = table;
        }
    }

    function doubleBet(PlayerState memory _table) internal {
        require(_table.playerCardCounter <= 2 && _table.splitBet == 0, "Cannot double now.");
        _table.bet = _table.bet.mul(2);
        uint8 card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
        _table.playerScore += card > 9 ? 10 : card == 1 ? 11 : card;
        _table.playerCardCounter = _table.playerCardCounter++;
        if (card == 1) _table.playerAceCounter += 1;
        if (_table.playerScore > 21) {
            if (_table.playerAceCounter > 0) {
                _table.playerAceCounter--;
                _table.playerScore -= 10;
                houseTurn(_table);
            } else {
                _table.bet = 0;
                players[msg.sender] = _table;
            }
        } else {
            houseTurn(_table);
        }
    }

    function split(PlayerState memory _table) internal {
        _table.splitBet = msg.value;

        uint8 card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
        _table.playerScore += card > 9 ? 10 : card == 1 ? 11 : card;
        _table.playerCardCounter = 2;
        if (card == 1) _table.playerAceCounter += 1;
        if (_table.playerScore == 22) {
            _table.playerAceCounter == 1;
            _table.playerScore = 12;
        }

        card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
        _table.playerSplitScore += card > 9 ? 10 : card == 1 ? 11 : card;
        _table.playerSplitCardCounter = 2;
        if (card == 1) _table.playerSplitAceCounter += 1;
        if (_table.playerSplitScore == 22) {
            _table.playerSplitAceCounter == 1;
            _table.playerSplitScore = 12;
        }
        players[msg.sender] = _table;
    }

    function hitFirst(PlayerState memory _table) internal {
        uint8 card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
        _table.playerScore += card > 9 ? 10 : card == 1 ? 11 : card;
        _table.playerCardCounter++;
        if (card == 1) _table.playerAceCounter += 1;
        if (_table.playerScore == 21 && (_table.playerSplitScore == 0 || _table.playerSplitScore == 21)) {
            houseTurn(_table);
        } else {
            if (_table.playerScore > 21) {
                if (_table.playerAceCounter > 0) {
                    _table.playerAceCounter--;
                    _table.playerScore -= 10;
                } else {
                    _table.bet = 0;
                }
            }
            players[msg.sender] = _table;
        }
    }

    function hitSecond(PlayerState memory _table) internal {
        uint8 card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
        _table.playerSplitScore += card > 9 ? 10 : card == 1 ? 11 : card;
        _table.playerSplitCardCounter++;
        if (card == 1) _table.playerSplitAceCounter += 1;
        if (_table.playerSplitScore == 21 && _table.playerScore == 21) {
            houseTurn(_table);
        } else {
            if (_table.playerSplitScore > 21) {
                if (_table.playerSplitAceCounter > 0) {
                    _table.playerSplitAceCounter--;
                    _table.playerSplitScore -= 10;
                } else {
                    _table.splitBet = 0;
                }
            }
            players[msg.sender] = _table;
        }
    }

    function houseTurn(PlayerState memory _table) internal {
        address payable playerAddress = address(uint160(msg.sender));

        uint8 card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
        _table.houseCardCounter++;
        _table.houseScore += card > 9 ? 10 : card == 1 ? 11 : card;
        if (card == 1) _table.houseAceCounter++;
        if (_table.houseScore == 22) {
            _table.playerAceCounter = 1;
            _table.houseScore = 12;
        }

        if (_table.playerScore == 21 && _table.playerCardCounter == 2 && _table.splitBet == 0) {
            if (_table.houseScore == 21 && _table.houseCardCounter == 2) {
               playerAddress.transfer(_table.bet.mul(1));
            } else {
                playerAddress.transfer(_table.bet.mul(5).div(2));
            }
            _table.bet = 0;
        } else {
            if (_table.houseScore == 17 && _table.houseAceCounter == 1) {
                card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
                _table.houseCardCounter++;
                _table.houseScore += card > 9 ? 10 : card == 1 ? 11 : card;
                if (card == 1) _table.houseAceCounter++;
            }
            while (_table.houseScore < 17) {
                card = uint8(uint(keccak256(abi.encodePacked(msg.sender, now, ++nonce))) % 13 + 1);
                _table.houseCardCounter++;
                _table.houseScore += card > 9 ? 10 : card == 1 ? 11 : card;
                if (card == 1) _table.houseAceCounter = _table.houseAceCounter++;
                if (_table.houseScore > 21) {
                    if (_table.houseAceCounter > 0) {
                        _table.houseAceCounter--;
                        _table.houseScore -= 10;
                    } else {
                        break;
                    }
                }
            }
            uint256 gains;
            if (_table.houseScore > 21 || _table.houseScore < _table.playerScore) gains = _table.bet.mul(2);
            else if (_table.houseScore == _table.playerScore && (_table.houseScore != 21 || _table.houseCardCounter != 2)) gains = _table.bet;
            _table.bet = 0;
            if (_table.splitBet != 0) {
                if (_table.houseScore > 21 || _table.houseScore < _table.playerSplitScore) gains += _table.splitBet.mul(2);
                else if (_table.houseScore == _table.playerSplitScore && (_table.houseScore != 21 || _table.houseCardCounter != 2)) gains += _table.splitBet;
                _table.splitBet = 0;
            }
            playerAddress.transfer(gains);
        }
        players[msg.sender] = _table;
    }

    function play(uint8 _action) external payable inGame(msg.sender) {
        require(_action < 6, 'Not a recognised action.');
        PlayerState memory table = players[msg.sender];
        if (table.playerCardCounter == 1) {
            if (_action == 5) {
                require(msg.value == table.bet, 'The same bet is required.');
                split(table);
                return;
            } else {
                table.playerScore += table.playerSplitScore;
                table.playerAceCounter += table.playerSplitAceCounter;
                table.playerCardCounter = 2;
                table.playerSplitScore = 0;
                table.playerSplitAceCounter = 0;
                table.playerSplitCardCounter = 0;
                if (table.playerScore == 22) {
                    table.playerAceCounter = 1;
                    table.playerScore = 12;
                }
            }
        }
        require(_action < 5, 'Impossible to split now.');
        if (_action == 1) {
            hitFirst(table);
        } else if (_action == 0) {
            houseTurn(table);
        } else if (_action == 4) {
            require(msg.value == table.bet, 'The same bet is required.');
            require(table.playerCardCounter == 2, 'Too many card too double.');
            doubleBet(table);
        } else if (_action == 2) {
            hitSecond(table);
        } else if (_action == 3) {
            hitFirst(table);
            table = players[msg.sender];
            hitSecond(table);
        }
    }

    function setMinMaxBet(uint256 _minBet, uint256 _maxBet) external onlyOwner {
        minimumBet = _minBet;
        maximumBet = _maxBet;
    }

    function getPlayerState(address _player) external view returns(uint256, uint256, uint8, uint8, uint8, uint8, uint8, uint8, uint8, uint8, uint8) {
        PlayerState memory table = players[_player];
        return (table.bet, table.splitBet,
        table.houseScore, table.houseAceCounter, table.houseCardCounter,
        table.playerScore, table.playerAceCounter, table.playerCardCounter,
        table.playerSplitScore, table.playerSplitAceCounter, table.playerSplitCardCounter);
    }

    function manageFunds(uint256 _value) external payable onlyOwner {
        if (_value != 0) msg.sender.transfer(_value);
    }

    function close() external onlyOwner {
        selfdestruct(owner);
    }

    function() external {}

    modifier notInGame(address _player) {
        require(players[_player].bet == 0 && players[_player].splitBet == 0, "Already in a game.");
        _;
    }

    modifier inGame(address _player) {
        require(players[_player].bet != 0 || players[_player].splitBet != 0, "Not in a game.");
        _;
    }
}
