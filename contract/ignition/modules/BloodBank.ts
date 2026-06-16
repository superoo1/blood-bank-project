import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const BloodBankModule = buildModule("BloodBankModule", (m) => {
    const bloodBank = m.contract("BloodBank");
    return { bloodBank };
});

export default BloodBankModule;