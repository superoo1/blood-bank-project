import { expect } from "chai";
import hre from "hardhat";

describe("BloodBank", function () {

    async function deployFixture() {
        const conn      = await hre.network.connect();
        const ethers    = conn.ethers;
        const signers   = await ethers.getSigners();

        const admin       = signers[0];
        const hospital    = signers[1];
        const transporter = signers[2];
        const other       = signers[3];

        const factory   = await ethers.getContractFactory("BloodBank");
        const bloodBank = await factory.deploy();
        await bloodBank.waitForDeployment();

        const HOSPITAL_ROLE    = await bloodBank.HOSPITAL_ROLE();
        const TRANSPORTER_ROLE = await bloodBank.TRANSPORTER_ROLE();

        await bloodBank.assignHospital(hospital.address);
        await bloodBank.assignTransporter(transporter.address);

        return {
            bloodBank, ethers,
            admin, hospital, transporter, other,
            HOSPITAL_ROLE, TRANSPORTER_ROLE
        };
    }

    it("Test 1: Admin can register a blood unit", async function () {
        const { bloodBank } = await deployFixture();

        await bloodBank.registerBloodUnit(
            "BLD001", "DNR001", "A+",
            "WholeBlood", 4, 3628800, 350
        );

        const record = await bloodBank.getBloodUnit("BLD001");
        expect(record.bloodID).to.equal("BLD001");
        expect(record.bloodGroup).to.equal("A+");
        expect(record.amount).to.equal(350n);
        expect(record.state).to.equal(0n);
    });

    it("Test 2: Hospital can request blood", async function () {
        const { bloodBank, hospital } = await deployFixture();

        await bloodBank.registerBloodUnit(
            "BLD002", "DNR002", "B+",
            "Platelets", 22, 432000, 200
        );

        await bloodBank.connect(hospital).requestBlood("BLD002");

        const record = await bloodBank.getBloodUnit("BLD002");
        expect(record.state).to.equal(1n);
    });

    it("Test 3: Cannot register duplicate Blood ID", async function () {
        const { bloodBank } = await deployFixture();

        await bloodBank.registerBloodUnit(
            "BLD003", "DNR003", "O-",
            "Plasma", 4, 3628800, 350
        );

        await expect(
            bloodBank.registerBloodUnit(
                "BLD003", "DNR004", "O+",
                "WholeBlood", 4, 3628800, 350
            )
        ).to.be.revertedWith("BloodID already exists");
    });

    it("Test 4: Non-admin cannot register blood", async function () {
        const { bloodBank, other, ethers } = await deployFixture();

        await expect(
            bloodBank.connect(other).registerBloodUnit(
                "BLD004", "DNR004", "AB+",
                "WholeBlood", 4, 3628800, 350
            )
        ).to.be.revert(ethers);
    });

    it("Test 5: Admin can mark blood as expired", async function () {
        const { bloodBank } = await deployFixture();

        await bloodBank.registerBloodUnit(
            "BLD005", "DNR005", "AB-",
            "RedBloodCells", 4, 3628800, 350
        );

        await bloodBank.markExpired("BLD005");

        const record = await bloodBank.getBloodUnit("BLD005");
        expect(record.state).to.equal(3n);
    });

    it("Test 6: Get all registered blood IDs", async function () {
        const { bloodBank } = await deployFixture();

        await bloodBank.registerBloodUnit(
            "BLD006", "DNR006", "A-",
            "WholeBlood", 4, 3628800, 350
        );
        await bloodBank.registerBloodUnit(
            "BLD007", "DNR007", "B-",
            "Plasma", 4, 3628800, 300
        );

        const ids = await bloodBank.getAllBloodIDs();
        expect(ids.length).to.equal(2);
        expect(ids[0]).to.equal("BLD006");
        expect(ids[1]).to.equal("BLD007");
    });
});