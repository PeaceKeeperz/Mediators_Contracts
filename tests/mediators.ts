import { ethers, run } from "hardhat";
import { Signer } from "ethers";
import { expect, assert } from "chai";

describe("Keepers Contract", () => {
    let accounts: Signer[];

  before(async () => {
    await run("compile");
  });

  beforeEach(async () => {
    const contractName: string = "Keepers";
    accounts = await ethers.getSigners();
      const factoryContract = await ethers.getContractFactory(contractName);
  });
});
