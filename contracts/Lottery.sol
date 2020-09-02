// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

contract Lottery {
    struct BetInfo {
        uint256 answerBlockNumber;
        address payable bettor;
        bytes1 challenges;
    }

    uint256 private _tail;
    uint256 private _head;
    mapping(uint256 => BetInfo) private _bets;

    address public owner;

    uint256 internal constant BLOCK_LIMIT = 256;
    uint256 internal constant BET_BLOCK_INTERVAL = 3;
    uint256 internal constant BET_AMOUNT = 5 * 10**15;
    uint256 private _pot;

    bool private mode = false;

    enum BlockStatus {Checkable, NotRevealed, BlockLimitPassed}
    enum BettingResult {Fail, Win, Draw}

    event BET(
        uint256 index,
        address bettor,
        uint256 amount,
        bytes1 challenges,
        uint256 answerBlockNumber
    );

    constructor() public {
        owner = msg.sender;
    }

    function getSomeValue() public pure returns (uint256 value) {
        return 5;
    }

    function getPot() public view returns (uint256 pot) {
        return _pot;
    }

    /**
     * @dev 배팅을 한다. 유저는 0.005 ETH를 보내야 한다. 배팅용 1 byte 글자를 보낸다.
     * 큐에 저장된 베팅 정보는 이후 distrubute 함수에서 해결된다.
     * @param challenges 유저가 배팅하는 글자.
     * @return result 함수가 잘 수행 되었는 지 확인하는 bool 값.
     */
    function bet(bytes1 challenges) public payable returns (bool result) {
        //check the proper ether was sent
        require(msg.value == BET_AMOUNT, "not enough ETH");
        require(pushBet(challenges), "Fail to add a new Bet Info");
        emit BET(
            _tail - 1,
            msg.sender,
            msg.value,
            challenges,
            block.number + BET_BLOCK_INTERVAL
        );
        //push log
        //event log
        return true;
    }

    //save the bet to the queue

    //Distribute
    function distrubute() public {
        uint256 cur;
        BetInfo memory b;
        BlockStatus currentBlockStatus;
        BettingResult currentBettingResult;

        for (cur = _head; cur < _tail; cur++) {
            b = _bets[cur];
            currentBlockStatus = getBlockStatus(b.answerBlockNumber);
            //checkable : block.number > AnswerBlockNumber && block.number < BLOCK_LIMIT + AnswerBlockNumber
            if (currentBlockStatus == BlockStatus.Checkable) {
                currentBettingResult = isMatch(
                    b.challenges,
                    blockhash(b.answerBlockNumber)
                );
                // if win, bettor gets money
                // if fail, bettor money goes to pot
                // if draw, refund bettor's money
            }
            //not revealed: block.number <= AnswerBlockNumber
            if (currentBlockStatus == BlockStatus.NotRevealed) {
                break;
            }
            //block limit passed: block.number >= AnswerBlockNumber + BLOCK_LIMIT
            if (currentBlockStatus == BlockStatus.BlockLimitPassed) {
                //refund
                //emit refund
            }
            popBet(cur);
            //check the answer
        }
    }

    // @dev 배팅글자와 정답을 확인한다.
    // @param challenges 베터가 배팅한 글자
    // @param answer 블랙해쉬값
    // @return 정답결과

    function isMatch(bytes1 challenges, bytes32 answer)
        public
        pure
        returns (BettingResult)
    {
        // challenges 0xab
        // answer 0xab ....ff 32bytes
        bytes1 c1 = challenges;
        bytes1 c2 = challenges;
        bytes1 a1 = answer[0];
        bytes1 a2 = answer[0];

        //get first number
        c1 = c1 >> 4; //0xab -> 0x0a
        c1 = c1 << 4; //0x0a -> 0xa0

        a1 = a1 >> 4;
        a1 = a1 << 4;

        //get second number
        c2 = c2 << 4; // 0xab -> 0xb0
        c2 = c2 >> 4; // 0xb0 -> 0x0b

        a2 = a2 << 4;
        a2 = a2 >> 4;

        if (a1 == c1 && a2 == c2) {
            return BettingResult.Win;
        }
        if (a1 == c1 || a2 == c2) {
            return BettingResult.Draw;
        }
        if (a1 != c1 && a2 != c2) {
            return BettingResult.Fail;
        }
    }

    function getBlockStatus(uint256 answerBlockNumber)
        internal
        view
        returns (BlockStatus)
    {
        if (
            block.number > answerBlockNumber &&
            block.number < BLOCK_LIMIT + answerBlockNumber
        ) {
            return BlockStatus.Checkable;
        }
        if (block.number <= answerBlockNumber) {
            return BlockStatus.NotRevealed;
        }
        if (block.number >= answerBlockNumber + BLOCK_LIMIT) {
            return BlockStatus.BlockLimitPassed;
        }
        return BlockStatus.BlockLimitPassed;
    }

    function getBetInfo(uint256 index)
        public
        view
        returns (
            uint256 answerBlockNumber,
            address bettor,
            bytes1 challenges
        )
    {
        BetInfo memory b = _bets[index];
        answerBlockNumber = b.answerBlockNumber;
        bettor = b.bettor;
        challenges = b.challenges;
    }

    function pushBet(bytes1 challenges) internal returns (bool) {
        BetInfo memory b;
        b.bettor = msg.sender; // 20byte 20000gas
        b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL; //32byte  20000gas
        b.challenges = challenges; //byte

        _bets[_tail] = b;
        _tail++; //32byte 20000gas 또 값을 바꿀때 5000gas

        return true;
    }

    function popBet(uint256 index) internal returns (bool) {
        delete _bets[index];
        return true;
    }
}
