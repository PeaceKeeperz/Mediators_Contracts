/* eslint-disable prettier/prettier */
/* eslint-disable import/no-duplicates */
import { ethers } from "hardhat";
import hre from "hardhat";

const main = async () => {
  const Mediator = await ethers.getContractFactory("Mediators");
  const mediator = await Mediator.deploy();
  await mediator.deployed();

  console.log("Mediator is deployed on ", mediator.address);
  console.log("Sleeping.......");
  await sleep(400000);

  await hre.run("verify:verify", {
    address: mediator.address,
    constructorArguments: [],
  });
};

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
