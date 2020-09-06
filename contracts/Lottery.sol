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

    address payable public owner;

    uint256 internal constant BLOCK_LIMIT = 256;
    uint256 internal constant BET_BLOCK_INTERVAL = 3;
    uint256 internal constant BET_AMOUNT = 5 * 10**15;
    uint256 private _pot;

    bool private mode = false; // false: test mode, true: real mode
    bytes32 public answerForTest;

    enum BlockStatus {Checkable, NotRevealed, BlockLimitPassed}
    enum BettingResult {Fail, Win, Draw}

    event BET(
        uint256 index,
        address bettor,
        uint256 amount,
        bytes1 challenges,
        uint256 answerBlockNumber
    );
    event WIN(
        uint256 index,
        address bettor,
        uint256 amount,
        bytes1 challenges,
        bytes1 answer,
        uint256 answerBlockNumber
    );
    event FAIL(
        uint256 index,
        address bettor,
        uint256 amount,
        bytes1 challenges,
        bytes1 answer,
        uint256 answerBlockNumber
    );
    event DRAW(
        uint256 index,
        address bettor,
        uint256 amount,
        bytes1 challenges,
        bytes1 answer,
        uint256 answerBlockNumber
    );
    event REFUND(
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
     * @dev 배팅과 정답체크를 한다. 유저는 0.005 ETH를 보내야 한다. 배팅용 1 byte 글자를 보낸다.
     * 큐에 저장된 베팅 정보는 이후 distrubute 함수에서 해결된다.
     * @param challenges 유저가 배팅하는 글자.
     * @return result 함수가 잘 수행 되었는 지 확인하는 bool 값.
     */

    function betAndDistribute(bytes1 challenges)
        public
        payable
        returns (bool result)
    {
        bet(challenges);
        distrubute();
        return true;
    }

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
    /**
     * @dev 베팅 결과 값을 확인 하고 팟머니를 분배한다.
     * 정답실퍠: 팟머니 축적, 정답 맞춤 : 팟머니 획득, 한글자 맞춤 혹은 정답확인 불가 : 베팅금액만 획득
     */
    function distrubute() public {
        uint256 cur;
        uint256 transferAmount;

        BetInfo memory b;
        BlockStatus currentBlockStatus;
        BettingResult currentBettingResult;

        for (cur = _head; cur < _tail; cur++) {
            b = _bets[cur];
            currentBlockStatus = getBlockStatus(b.answerBlockNumber);
            //checkable : block.number > AnswerBlockNumber && block.number < BLOCK_LIMIT + AnswerBlockNumber
            if (currentBlockStatus == BlockStatus.Checkable) {
                bytes32 answerBlockHash = getAnswerBlockHash(
                    b.answerBlockNumber
                );
                currentBettingResult = isMatch(b.challenges, answerBlockHash);
                // if win, bettor gets pot
                if (currentBettingResult == BettingResult.Win) {
                    // transfer pot
                    transferAmount = transferAfterPayingFee(
                        b.bettor,
                        _pot + BET_AMOUNT
                    );
                    // pot = 0
                    _pot = 0;
                    // emit event WIN
                    emit WIN(
                        cur,
                        b.bettor,
                        transferAmount,
                        b.challenges,
                        answerBlockHash[0],
                        b.answerBlockNumber
                    );
                }
                // if fail, bettor money goes to pot
                if (currentBettingResult == BettingResult.Fail) {
                    // pot = pot + BET_AMOUNT
                    _pot += BET_AMOUNT;
                    // emit event FAIL
                    emit FAIL(
                        cur,
                        b.bettor,
                        0,
                        b.challenges,
                        answerBlockHash[0],
                        b.answerBlockNumber
                    );
                }
                // if draw, refund bettor's money
                if (currentBettingResult == BettingResult.Draw) {
                    // transfer only BET_AMOUNT
                    transferAmount = transferAfterPayingFee(
                        b.bettor,
                        BET_AMOUNT
                    );
                    // emit event DRAW
                    emit DRAW(
                        cur,
                        b.bettor,
                        transferAmount,
                        b.challenges,
                        answerBlockHash[0],
                        b.answerBlockNumber
                    );
                }
            }
            //not revealed: block.number <= AnswerBlockNumber
            if (currentBlockStatus == BlockStatus.NotRevealed) {
                break;
            }
            //block limit passed: block.number >= AnswerBlockNumber + BLOCK_LIMIT
            if (currentBlockStatus == BlockStatus.BlockLimitPassed) {
                //refund
                transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
                //emit refund
                emit REFUND(
                    cur,
                    b.bettor,
                    transferAmount,
                    b.challenges,
                    b.answerBlockNumber
                );
            }
            popBet(cur);
            //check the answer
        }
        _head = cur;
    }

    function transferAfterPayingFee(address payable addr, uint256 amount)
        internal
        returns (uint256)
    {
        // uint256 fee = amount / 100;
        uint256 fee = 0;
        uint256 amountWithoutFee = amount - fee;
        // transfer to addr
        addr.transfer(amountWithoutFee);
        // transfer to owner
        owner.transfer(fee);
        return amountWithoutFee;
    }

    function setAnswerForTest(bytes32 answer) public returns (bool result) {
        require(
            msg.sender == owner,
            "Only owner can set the answer for test mode"
        );
        answerForTest = answer;
        return true;
    }

    function getAnswerBlockHash(uint256 answerBlockNumber)
        internal
        view
        returns (bytes32 answer)
    {
        return mode ? blockhash(answerBlockNumber) : answerForTest;
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
