// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BloodBank is ReentrancyGuard, AccessControl {

    // ═══════════════════════════════════════
    //  ROLES
    // ═══════════════════════════════════════
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant USER_ROLE  = keccak256("USER_ROLE");

    // ═══════════════════════════════════════
    //  ENUMS & STRUCTS
    // ═══════════════════════════════════════
    enum BloodStatus { Stored, InTransit, Used, Expired }

    struct StatusHistory {
        BloodStatus status;
        uint256     timestamp;
        address     updatedBy;
    }

    struct BloodRecord {
        string      bloodID;
        string      donorID;
        string      bloodGroup;
        string      bloodProduction;
        int256      temperature;
        uint256     collectionTime;
        uint256     expiryDuration;
        BloodStatus state;
        address     medicalFacility;
        uint256     amount;
    }

    // ═══════════════════════════════════════
    //  STORAGE
    // ═══════════════════════════════════════
    mapping(string => BloodRecord)     private bloodRecords;
    mapping(string => StatusHistory[]) private bloodHistory;
    string[]  private bloodIDs;
    address[] private userList;
    address[] private adminList;
    mapping(address => bool) private userExists;
    mapping(address => bool) private adminExists;

    // ═══════════════════════════════════════
    //  EVENTS
    // ═══════════════════════════════════════
    event UserLoggedIn    (address indexed account, uint256 time);
    event BloodRegistered (address indexed account, string bloodID, string bloodGroup, uint256 time);
    event BloodRequested  (address indexed account, string bloodID, uint256 time);
    event StatusUpdated   (address indexed account, string bloodID, BloodStatus status, uint256 time);
    event AdminAssigned   (address indexed account, address indexed target, uint256 time);
    event UserAssigned    (address indexed account, address indexed target, uint256 time);
    event UserRevoked     (address indexed account, address indexed target, uint256 time);
    event AdminRevoked    (address indexed account, address indexed target, uint256 time);

    // ═══════════════════════════════════════
    //  CONSTRUCTOR
    // ═══════════════════════════════════════
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(USER_ROLE,  msg.sender);
        adminList.push(msg.sender);
        adminExists[msg.sender] = true;
        userList.push(msg.sender);
        userExists[msg.sender] = true;
    }

    // ═══════════════════════════════════════
    //  RECORD LOGIN
    // ═══════════════════════════════════════
    function recordLogin() public {
        emit UserLoggedIn(msg.sender, block.timestamp);
    }

    // ═══════════════════════════════════════
    //  USER FUNCTIONS
    // ═══════════════════════════════════════
    function registerBloodUnit(
        string memory _bloodID,
        string memory _donorID,
        string memory _bloodGroup,
        string memory _bloodProduction,
        int256        _temperature,
        uint256       _expiryDuration,
        uint256       _amount
    ) public {
        require(bytes(_bloodID).length > 0,    "BloodID cannot be empty");
        require(bytes(_donorID).length > 0,    "DonorID cannot be empty");
        require(bytes(_bloodGroup).length > 0, "Blood group required");
        require(_amount > 0,                   "Amount must be > 0");
        require(
            bytes(bloodRecords[_bloodID].bloodID).length == 0,
            "BloodID already exists"
        );

        bloodRecords[_bloodID] = BloodRecord({
            bloodID:         _bloodID,
            donorID:         _donorID,
            bloodGroup:      _bloodGroup,
            bloodProduction: _bloodProduction,
            temperature:     _temperature,
            collectionTime:  block.timestamp,
            expiryDuration:  _expiryDuration,
            state:           BloodStatus.Stored,
            medicalFacility: msg.sender,
            amount:          _amount
        });

        bloodHistory[_bloodID].push(StatusHistory({
            status:    BloodStatus.Stored,
            timestamp: block.timestamp,
            updatedBy: msg.sender
        }));

        bloodIDs.push(_bloodID);
        emit BloodRegistered(msg.sender, _bloodID, _bloodGroup, block.timestamp);
    }

    function requestBlood(string memory _bloodID) public {
        require(
            bytes(bloodRecords[_bloodID].bloodID).length > 0,
            "Blood unit not found"
        );
        require(
            bloodRecords[_bloodID].state == BloodStatus.Stored,
            "Blood is not available"
        );

        bloodRecords[_bloodID].state           = BloodStatus.InTransit;
        bloodRecords[_bloodID].medicalFacility = msg.sender;

        bloodHistory[_bloodID].push(StatusHistory({
            status:    BloodStatus.InTransit,
            timestamp: block.timestamp,
            updatedBy: msg.sender
        }));

        emit BloodRequested(msg.sender, _bloodID, block.timestamp);
    }

    function getBloodByGroup(string memory _bloodGroup)
        public view returns (BloodRecord[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < bloodIDs.length; i++) {
            if (keccak256(bytes(bloodRecords[bloodIDs[i]].bloodGroup)) ==
                keccak256(bytes(_bloodGroup)) &&
                bloodRecords[bloodIDs[i]].state == BloodStatus.Stored) {
                count++;
            }
        }
        BloodRecord[] memory results = new BloodRecord[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < bloodIDs.length; i++) {
            if (keccak256(bytes(bloodRecords[bloodIDs[i]].bloodGroup)) ==
                keccak256(bytes(_bloodGroup)) &&
                bloodRecords[bloodIDs[i]].state == BloodStatus.Stored) {
                results[index] = bloodRecords[bloodIDs[i]];
                index++;
            }
        }
        return results;
    }

    function getBloodUnit(string memory _bloodID)
        public view returns (BloodRecord memory) {
        require(
            bytes(bloodRecords[_bloodID].bloodID).length > 0,
            "Blood unit not found"
        );
        return bloodRecords[_bloodID];
    }

    function getBloodHistory(string memory _bloodID)
        public view returns (StatusHistory[] memory) {
        require(
            bytes(bloodRecords[_bloodID].bloodID).length > 0,
            "Blood unit not found"
        );
        return bloodHistory[_bloodID];
    }

    // ═══════════════════════════════════════
    //  ADMIN ONLY FUNCTIONS
    // ═══════════════════════════════════════
    function markUsed(string memory _bloodID)
        public onlyRole(ADMIN_ROLE) {
        require(
            bytes(bloodRecords[_bloodID].bloodID).length > 0,
            "Blood unit not found"
        );
        bloodRecords[_bloodID].state = BloodStatus.Used;
        bloodHistory[_bloodID].push(StatusHistory({
            status:    BloodStatus.Used,
            timestamp: block.timestamp,
            updatedBy: msg.sender
        }));
        emit StatusUpdated(msg.sender, _bloodID, BloodStatus.Used, block.timestamp);
    }

    function markExpired(string memory _bloodID)
        public onlyRole(ADMIN_ROLE) {
        require(
            bytes(bloodRecords[_bloodID].bloodID).length > 0,
            "Blood unit not found"
        );
        bloodRecords[_bloodID].state = BloodStatus.Expired;
        bloodHistory[_bloodID].push(StatusHistory({
            status:    BloodStatus.Expired,
            timestamp: block.timestamp,
            updatedBy: msg.sender
        }));
        emit StatusUpdated(msg.sender, _bloodID, BloodStatus.Expired, block.timestamp);
    }

    function getAllBloodIDs()
        public view onlyRole(ADMIN_ROLE)
        returns (string[] memory) {
        return bloodIDs;
    }

    function assignAdmin(address _newAdmin)
        public onlyRole(ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, _newAdmin);
        if (!adminExists[_newAdmin]) {
            adminList.push(_newAdmin);
            adminExists[_newAdmin] = true;
        }
        emit AdminAssigned(msg.sender, _newAdmin, block.timestamp);
    }

    function assignUser(address _newUser)
        public onlyRole(ADMIN_ROLE) {
        _grantRole(USER_ROLE, _newUser);
        if (!userExists[_newUser]) {
            userList.push(_newUser);
            userExists[_newUser] = true;
        }
        emit UserAssigned(msg.sender, _newUser, block.timestamp);
    }

    function revokeUser(address _user)
        public onlyRole(ADMIN_ROLE) {
        _revokeRole(USER_ROLE, _user);
        emit UserRevoked(msg.sender, _user, block.timestamp);
    }

    function revokeAdmin(address _admin)
        public onlyRole(ADMIN_ROLE) {
        require(
            _admin != msg.sender,
            "Cannot revoke your own admin role"
        );
        _revokeRole(ADMIN_ROLE, _admin);
        emit AdminRevoked(msg.sender, _admin, block.timestamp);
    }

    function isAdmin(address _addr) public view returns (bool) {
        return hasRole(ADMIN_ROLE, _addr);
    }

    function isUser(address _addr) public view returns (bool) {
        return hasRole(USER_ROLE, _addr);
    }

    function getAllUsers()
        public view onlyRole(ADMIN_ROLE)
        returns (address[] memory) {
        return userList;
    }

    function getAllAdmins()
        public view onlyRole(ADMIN_ROLE)
        returns (address[] memory) {
        return adminList;
    }
}