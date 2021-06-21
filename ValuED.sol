// SPDX-License-Identifier: 
pragma solidity ^0.5.0;

/**
 * @author A B
 * @title ValuED contract - for cognitive science project
 */
contract ValuED {
    
    address public owner;
    int public constant MAX_SCORE = 5;
    int public constant MIN_SCORE = -5;
    uint public constant LECTURE_TOKENS = 5; // it keeps a fixed number of tokens.
    uint public transactionsCount; // it's used as transaction's ID too.
    uint public proposalsCount;
    uint public currentLectureNumber;
    mapping (uint => StudentStatus) public studentStatus; 
    mapping (uint => Proposal) public proposals;
    mapping (address => bool) public validStudent;
    mapping (address => bool) public validAdmin;
    mapping (address => uint) public studentTokenBalance;
    mapping (address => uint) public tradedTokens; // keeps track of total tokens sent/recived by each student.
    mapping (address  => int) public reputations; // mapping (address reciver  => int score) 
    mapping (uint => Transaction) public transactions; // mapping (uint transaction id/counter => Transaction)
    mapping (uint => bytes2) public hashLectureID; // lecture number => hash(lecture ID).
    mapping (address => uint) public attended; 
    mapping (uint => uint) public lectureParticipants;// (uint lecture_number => uint number_of_students_claimed_tokens) lectureParticipants--  It stores  total number of students participated in a session/lecture
    
    struct StudentStatus {
        bool valid;
        bool tokenAssigned;
    }
    
    struct Proposal {
        uint tokens;
        address creator;
        string email;// this is needed because the student that makes an offer may want to send token. 
        // in this case, the student who is interested can email and send to it, its public key. Then, the student who 
        // has made the offer can call sendToken() and uses the other student's address as the recipient. 
        string reason;
        uint id;
        bool active;
    }

    struct Transaction{
        
        address sender;
        address reciever;
        string reason; 
        int senderFeedback; // feedback provided by the sender to tokens.
        int receiverFeedback; // feedback provided by  the reciever of tokens.
        uint id;
        uint tokens; // number of tokens sent in this transaction.
        string creationTime;
    }
    
    constructor(address admin) public{
        
        owner = msg.sender;
        validAdmin[admin] = true;
        validAdmin[msg.sender] = true; // so the deployer can be admin too.
    }
    
    modifier onlyAdmin(){
        
        require(validAdmin[msg.sender] == true);
        _;
    }
    
    modifier onlyOwner(){
        
        require(msg.sender == owner);
        _;
    }
    
    function addAdmin(address admin) external onlyOwner{
        
        validAdmin[admin] = true;
    }
    
    function delAdmin(address admin) external onlyOwner{
        
        validAdmin[admin] = false;
    }
    
    // Allows a valid admin to send some tokens to students.
    function distributeToken(address student, uint tokens) external onlyAdmin{
        
        require(validStudent[student] == true);
        studentTokenBalance[student] += tokens;
    }
    
    function register_std_num(uint std_num) external onlyAdmin{ // this is done when a list of students enroled for the course is finalised. 
        
        studentStatus[std_num].valid = true;
    }

    function register_student(address student, uint std_num) external onlyAdmin{
        
        require(studentStatus[std_num].valid == true); // check if the student has enrolled the course
        require(studentStatus[std_num].tokenAssigned == false); // ensures a student cannot registers itself with multiple public keys
        studentStatus[std_num].tokenAssigned = true;
         validStudent[student] = true;
         studentTokenBalance[student] = 10; // it allocates 10 tokens to the regitered student.
    }
    
    function registerLecture(uint lecture_number, string calldata lecture) external onlyAdmin{
        
        hashLectureID[lecture_number] = bytes2(keccak256(bytes(lecture)));// a hash value of the lecture is stored in the contract. 
    }
    
   function setCurrentLectureNumber(uint num) external onlyAdmin{
       
       currentLectureNumber = num;
   } 
     // This function allows a student to claim a fixed number of tokens (LECTURE_TOKENS), if it could prove its attentance in a lecture  (e.g. by uploading a QR code in the UI). If approved 
    // (in the UI) then UI calls this function. 
    function claimToken(string calldata input_) external{
        
        require(validStudent[msg.sender] == true);// checks if it's a valid student
        require(hashLectureID[currentLectureNumber] == bytes2(keccak256(bytes(input_))));//checks if the student has sent a valid id 
        require(attended[msg.sender] != currentLectureNumber);// ensures the student has not already claimed any tokens for this lecture yet.
        attended[msg.sender] = currentLectureNumber;
        studentTokenBalance[msg.sender] += LECTURE_TOKENS;
        lectureParticipants[currentLectureNumber]++;
    }
    
    // in the UI, each student should be able to see a list of active offers he/she has made. This allows the student
    // to fetch specific offer ID used in sendToken. //  
    // This function allows a student to post an offer on the UI. It can offer to engage in an actitivy and specify how many tokens it is willing to send or recieve.
    function makeProposal(uint tokens, string calldata reason, string calldata email) external{
        
        require(validStudent[msg.sender] == true, "Not a valid sender");
        require(studentTokenBalance[msg.sender] >= tokens,"Not enough token");
        Proposal memory proposal;
        proposal.tokens = tokens;
        proposal.creator = msg.sender;
        proposal.email = email;
        proposal.reason = reason;
        proposalsCount++;
        proposal.id = proposalsCount;
        proposal.active = true;
        proposals[proposalsCount] = proposal;
    }
    
    function sendToken(uint amount, address receiver, string calldata reason,string calldata time, uint proposalID) external{
        
        require(msg.sender!=receiver); // the sender should not be able to send token to itself and make a transaction. 
        require(validStudent[msg.sender] == true, "Not a valid sender"); // checks if the sender is a valid student
        require(validStudent[receiver] == true, "Not a valid recipient"); // checks if the recipient is a valid student
        require(studentTokenBalance[msg.sender] >= amount,"Not enough token");  // check if the sender has enough token.
        require(proposals[proposalID].active == true, "Not an active offer");//check of the offer is active yet.
        require(amount > 0);
        //either the token recipient or the token sender should be in the creator of the offer_ID.
        require(msg.sender == proposals[proposalID].creator || receiver == proposals[proposalID].creator);
        proposals[proposalID].active = false;// recall only active offers should be desplayed on the UI.
        studentTokenBalance[msg.sender] -= amount;
        studentTokenBalance[receiver] += amount;
        tradedTokens[msg.sender] += amount; 
        tradedTokens[receiver] += amount;
        Transaction memory transaction;
        // stores each transaction's details in "transactions".
        transactionsCount += 1;
        transaction.sender = msg.sender;
        transaction.reciever = receiver;
        transaction.reason = reason;
        transaction.tokens = amount; 
        transaction.creationTime = time;
        transaction.id = transactionsCount;
        transaction.senderFeedback = -10; // we allocate -10 to show no feedback has been provided. Note that 0 is among valid scores and it's also a default value for uint types. 
        transaction.receiverFeedback = -10; // see above
        transactions[transactionsCount] = transaction;
    }
    
    function canLeaveFeedback(address sender, uint transactionID) internal returns (bool can, uint res){ 
        
        // checks if the person who wants to leave the feedback is sender of tokens AND has not left any feedback for the transaction.
        if(transactions[transactionID].sender == sender && transactions[transactionID].senderFeedback == -10){
            res = 1;
            can = true;
        }
        // checks if the person who wants to leave the feedback is reciever of tokens AND has not left any feedback for the transaction.
        else if(transactions[transactionID].reciever == sender && transactions[transactionID].receiverFeedback == -10){
            res = 2;
            can = true;
        }
    }
    // the sender of the feedback needs to first check the list of the transactions and see which transaction it wants to leave feedback 
    // then it needs to read the transaction ID. 
    function leaveFeedback(uint transactionID, int score) external{
       
        require (MIN_SCORE <= score && score <= MAX_SCORE);  // check if the score is valid: MIN_SCORE <= score <= MAX_SCORE
        (bool can, uint res) = canLeaveFeedback(msg.sender, transactionID); // check if the the sender of the feedback is one of the parties involded in the transaction and has not already left any feedback yet. 
        require(can);
        if (res == 1){ 
            transactions[transactionID].senderFeedback = score; 
            reputations[transactions[transactionID].reciever] += score;
        }
        else if (res == 2){ 
            transactions[transactionID].receiverFeedback = score; 
            reputations[transactions[transactionID].sender] += score;
        }
    }
}