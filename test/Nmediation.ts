/* eslint-disable spaced-comment */
/* eslint-disable prettier/prettier */
import { ethers, run } from "hardhat";
import { Contract, ContractFactory, BigNumber } from "ethers";
import { expect, assert } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";



describe("Nmediation Contract", () => {
    let accounts: SignerWithAddress[];
    let mediator: Contract;
    let mediation: Contract;


  before(async () => {
    await run("compile");

    //deploying the mediator contract
    const Mediator = await ethers.getContractFactory("Mediators");
    mediator = await Mediator.deploy();
    await mediator.deployed();

    //deploying the mediation contract
    const Mediation = await ethers.getContractFactory("Mediation");
    mediation = await Mediation.deploy(4079, mediator.address);
    await mediation.deployed();
  });

  beforeEach(async () => {
    accounts = await ethers.getSigners();
  });
    
    describe("CreateCase function", () => {
        it("Should create a case struct", async () => {
            const category: number = 0;
            const sessionNum: number = 2;
            const sessionId: number[] = [];
            const params
           const newCase: Contract = await mediation.connect(accounts[1]).createCase(category, sessionId)
        })
    })
})