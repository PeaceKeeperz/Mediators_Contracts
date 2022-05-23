/* eslint-disable no-unused-vars */
/* eslint-disable spaced-comment */
/* eslint-disable prettier/prettier */
import { ethers, run } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import { expect, assert } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

describe("Mediators Contract", () => {
  let accounts: SignerWithAddress[];
  let mediators: Contract;
  let mediations: Contract;

  before(async () => {
    await run("compile");
  });

  beforeEach(async () => {
    const contractName: string = "Mediators";
    accounts = await ethers.getSigners();
    const mediatorsFC: ContractFactory = await ethers.getContractFactory(
      contractName
    );
    mediators = await mediatorsFC.deploy();
    await mediators.deployed();
  });

  describe("Mediator unit tests", () => {
    it("Should return the right contructor argument of owner", async () => {
      const owner: SignerWithAddress = await mediators.owner();
      assert(owner, accounts[0].address);
    });

    it("Should set the correct MediationContract address", async () => {
      const randomAddress = "0x1230000000000000000000000000000000000000";
      await mediators.connect(accounts[0]).setMediationContract(randomAddress);
      const contractAdd = await mediators.mediationContract();
      assert.equal(contractAdd, randomAddress, "Should set the right address");
    });

    describe("createMediator unit tests", () => {
      it("Should create a Mediator Struct", async () => {
        const owner: SignerWithAddress = accounts[0];
        const timezone: string = "PST";
        const languages: string = "English";
        const certification: string = "Some Cert";
        const daoExperience: boolean = true;

        const createMediator = await mediators
          .connect(owner)
          .createMediator(
            owner.address,
            timezone,
            languages,
            certification,
            daoExperience
          );
        const txReceipt = await createMediator.wait();
        const newMediator = await mediators.mediators(1);

        assert.equal(newMediator.id, 1, "mediator struct id should equal 1");
        assert.equal(
          newMediator.openCaseCount,
          0,
          "openCaseCount should equal 0"
        );
        assert.equal(
          newMediator.owner,
          owner.address,
          "owner address should be the same"
        );
        assert.equal(newMediator.timeZone, "PST", "timezone should be PST");
        assert.equal(
          newMediator.Languages,
          "English",
          "Languages should contain english and spanish"
        );
        assert.equal(
          newMediator.certifications,
          "Some Cert",
          "certifications should be equal"
        );
        assert.equal(
          newMediator.daoExperience,
          true,
          "Daoexperience should be true"
        );
        assert.equal(
          newMediator.timestamp,
          txReceipt.events[0].args.timestamp.toString(),
          "should have the right timestamp"
        );
      });

      it("Should emit correct Mediator Event", async () => {
        const owner: SignerWithAddress = accounts[0];
        const timezone: string = "PST";
        const languages: string = "English";
        const certification: string = "Some Cert";
        const daoExperience: boolean = true;

        const createMediator = await mediators
          .connect(owner)
          .createMediator(
            owner.address,
            timezone,
            languages,
            certification,
            daoExperience
          );

        const txReceipt = await createMediator.wait();

        await expect(createMediator)
          .to.emit(mediators, "Mediator")
          .withArgs(
            1,
            owner.address,
            0,
            "PST",
            "English",
            "Some Cert",
            true,
            txReceipt.events[0].args.timestamp.toString()
          );
      });

      it("Should set isAvailable to true", async () => {
        const owner: SignerWithAddress = accounts[0];
        const timezone: string = "PST";
        const languages: string = "English";
        const certification: string = "Some Cert";
        const daoExperience: boolean = true;

        const createMediator = await mediators
          .connect(owner)
          .createMediator(
            owner.address,
            timezone,
            languages,
            certification,
            daoExperience
          );

        const isAvailable: boolean = await mediators.isAvailable(1);
        assert.equal(isAvailable, true, "Availability should be true");
      });

      it("Should set isActive to true", async () => {
        const owner: SignerWithAddress = accounts[0];
        const timezone: string = "PST";
        const languages: string = "English";
        const certification: string = "Some Cert";
        const daoExperience: boolean = true;

        const createMediator = await mediators
          .connect(owner)
          .createMediator(
            owner.address,
            timezone,
            languages,
            certification,
            daoExperience
          );

        const isAvailable: boolean = await mediators.isActive(1);
        assert.equal(isAvailable, true, "isActive should be true");
      });

      it("Should update nextMediatorId", async () => {
        const owner: SignerWithAddress = accounts[0];
        const timezone: string = "PST";
        const languages: string = "English";
        const certification: string = "Some Cert";
        const daoExperience: boolean = true;

        await mediators
          .connect(owner)
          .createMediator(
            owner.address,
            timezone,
            languages,
            certification,
            daoExperience
          );

        const nextMediatorId = await mediators.nextMediatorId();
        assert.equal(nextMediatorId, 1, "Should equal 1");
      });

      it("Should updateMediator", async () => {
        const owner: SignerWithAddress = accounts[0];
        const timezone: string = "PST";
        const languages: string = "English";
        const certification: string = "Some Cert";
        const daoExperience: boolean = true;

        await mediators
          .connect(owner)
          .createMediator(
            owner.address,
            timezone,
            languages,
            certification,
            daoExperience
          );

        const category2Address = await mediators
          .connect(owner)
          .getAllMediators();
        assert.equal(category2Address[0], owner.address);
      });

      it("Should revert when createMediator is called by nonOwner", async () => {
        const account1: SignerWithAddress = accounts[1];
        const timezone: string = "PST";
        const languages: string = "English";
        const certification: string = "Some Cert";
        const daoExperience: boolean = true;
        await expect(
          mediators
            .connect(account1)
            .createMediator(
              account1.address,
              timezone,
              languages,
              certification,
              daoExperience
            )
        ).to.be.revertedWith(
          "You do not have permission to call this contract"
        );
      });
    });
  });

  describe("External function calls", () => {
    let mediationCase: Contract;

    beforeEach(async () => {
      const mediationFC: ContractFactory = await ethers.getContractFactory(
        "Mediation"
      );
      mediations = await mediationFC.deploy(4079, mediators.address);
      await mediations.deployed();

      //created a new mediation case

      mediationCase = await mediations.connect(accounts[4]).createCase(0, {
        value: ethers.utils.parseEther("0.0015"),
      });

      // creates a new mediator
      const owner: SignerWithAddress = accounts[0];
      const mediatorAddress: string =
        "0x1230000000000000000000000000000000000000";
      const timezone: string = "PST";
      const languages: string = "English";
      const certification: string = "Some Cert";
      const daoExperience: boolean = true;
      const category: number = 0;

      const createMediator = await mediators
        .connect(owner)
        .createMediator(
          mediatorAddress,
          timezone,
          languages,
          certification,
          daoExperience,
          category
        );
    });

    it("Should call addCaseCount and add casecount to Mediator struct", async () => {
      const caseId = await mediations.nextCaseId();
      await mediations.assignMediator(0, caseId);
      // const mediatorStruct = await mediators.mediators(1);
      // const caseCount = mediatorStruct.openCaseCount;
      // assert.equal(caseCount, 1, "OpenCase Count Should be 1");
    });

    // it("Should call minusCaseCount and subtract casecount to Mediator struct", async () => {
    //   assert.equal(false, true, "This test is not complete");
    // });

    // it("Should revert when minusCaseCount is called when the Mediator struct has no open cases.", async () => {
    //   assert.equal(false, true, "This test is not complete");
    // });
  });
});
