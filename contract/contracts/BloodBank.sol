// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BloodBank is ReentrancyGuard {

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

    mapping(string => BloodRecord)      private bloodRecords;
    mapping(string => StatusHistory[])  private bloodHistory;
    string[] private bloodIDs;

    event BloodRegistered  (string bloodID, string bloodGroup, uint256 time);
    event BloodRequested   (string bloodID, address requester, uint256 time);
    event StatusUpdated    (string bloodID, BloodStatus status, uint256 time);

    // ── FUNCTION 1: REGISTER ──────────────────
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

        // 记录初始状态历史
        bloodHistory[_bloodID].push(StatusHistory({
            status:    BloodStatus.Stored,
            timestamp: block.timestamp,
            updatedBy: msg.sender
        }));

        bloodIDs.push(_bloodID);
        emit BloodRegistered(_bloodID, _bloodGroup, block.timestamp);
    }

    // ── FUNCTION 2: REQUEST BLOOD ─────────────
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

        emit BloodRequested(_bloodID, msg.sender, block.timestamp);
    }

    // ── FUNCTION 3: MARK USED ─────────────────
    function markUsed(string memory _bloodID) public {
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

        emit StatusUpdated(_bloodID, BloodStatus.Used, block.timestamp);
    }

    // ── FUNCTION 4: MARK EXPIRED ──────────────
    function markExpired(string memory _bloodID) public {
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

        emit StatusUpdated(_bloodID, BloodStatus.Expired, block.timestamp);
    }

    // ── FUNCTION 5: GET BLOOD UNIT ────────────
    function getBloodUnit(string memory _bloodID)
        public view returns (BloodRecord memory) {
        require(
            bytes(bloodRecords[_bloodID].bloodID).length > 0,
            "Blood unit not found"
        );
        return bloodRecords[_bloodID];
    }

    // ── FUNCTION 6: GET HISTORY ───────────────
    function getBloodHistory(string memory _bloodID)
        public view returns (StatusHistory[] memory) {
        require(
            bytes(bloodRecords[_bloodID].bloodID).length > 0,
            "Blood unit not found"
        );
        return bloodHistory[_bloodID];
    }

    // ── FUNCTION 7: GET ALL IDs ───────────────
    function getAllBloodIDs()
        public view returns (string[] memory) {
        return bloodIDs;
    }
}