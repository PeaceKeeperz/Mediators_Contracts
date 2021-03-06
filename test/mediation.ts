/* eslint-disable spaced-comment */
/* eslint-disable prettier/prettier */
import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Integration Test for Mediator and Mediation contracts", () => {
  let mediation: Contract;
  let mediator: Contract;
  let accounts: SignerWithAddress[];
  //Running a "before", will run just once.
  before(async () => {
    //deploying the mediator contract
    const Mediator = await ethers.getContractFactory("Mediators");
    mediator = await Mediator.deploy();
    await mediator.deployed();

    //deploying the mediation contract
    const Mediation = await ethers.getContractFactory("Mediation");
    mediation = await Mediation.deploy(4079, mediator.address);
    await mediation.deployed();
  });

  //Running a beforeEach executes for every test case
  beforeEach(async () => {
    accounts = await ethers.getSigners();
  });

  describe("Mediator unit test", () => {
    it("Should create a new mediator", async () => {
      const lan = "en";
      const cert = "Masters";
      await mediator
        .connect(accounts[0])
        .createMediator(accounts[1].address, "GMT + 1", lan, cert, true);
      expect(await mediator.isAvailable(1)).to.equal(true);
    });

    it("should get mediators", async () => {
      const lan = "en";
      const cert = "Masters";
      await mediator
        .connect(accounts[0])
        .createMediator(accounts[2].address, "GMT + 1", lan, cert, true);
      await mediator
        .connect(accounts[0])
        .createMediator(accounts[3].address, "GMT + 1", lan, cert, true);
      const addresses = await mediator.getAllMediators();
      expect(addresses.length).to.equal(3);
    });
  });

  describe("Mediation unit test", () => {
    it("Party one should create a medation", async () => {
      await mediation.connect(accounts[4]).createCase({
        value: ethers.utils.parseEther("0.0015"),
      });
      const _case = await mediation.cases(1);
      expect(_case.firstParty).to.not.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });

    it("Should not join a closed Case", async () => {
      await expect(mediation.joinCase(1, 2)).to.revertedWith(
        "Mediation__CaseDoesNotExistOrCaseIsClosed()"
      );
    });

    it("Should join case as second party", async () => {
      await mediation.connect(accounts[5]).joinCaseAsSecondParty(1, {
        value: ethers.utils.parseEther("0.0015"),
      });
      const _case = await mediation.cases(1);
      expect(_case.secondParty).to.not.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });

    it("Should not join case that does not exist", async () => {
      await expect(
        mediation.connect(accounts[6]).joinCaseAsSecondParty(2, {
          value: ethers.utils.parseEther("0.0015"),
        })
      ).to.revertedWith("Mediation__CaseDoesNotExistOrCaseIsClosed()");
    });

    it("Should join first party", async () => {
      await mediation.connect(accounts[6]).joinCase(1, 1);
      const FirstMembers = await mediation.getFirstPartyMembers(1);
      expect(FirstMembers.length).to.equal(1);
    });

    it("Should join second party", async () => {
      await mediation.connect(accounts[7]).joinCase(1, 2);
      await mediation.connect(accounts[8]).joinCase(1, 2);
      const SecondMembers = await mediation.getSecondPartyMembers(1);
      expect(SecondMembers.length).to.equal(2);
    });

    it("Should not join a none existing party", async () => {
      await expect(mediation.joinCase(1, 3)).to.revertedWith(
        "Mediation__PartyDoesNotExist()"
      );
    });

    it("Should create case for the two parties", async () => {
      await mediation
        .connect(accounts[9])
        .companyCreateCase(accounts[1].address, accounts[2].address, {
          value: ethers.utils.parseEther("0.002"),
        });
      const _case = await mediation.cases(2);
      await expect(_case.caseClosed).is.equal(false);
    });
  });
});
