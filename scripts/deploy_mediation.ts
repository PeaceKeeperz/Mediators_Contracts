/* eslint-disable prettier/prettier */
/* eslint-disable import/no-duplicates */
import { ethers } from "hardhat";
import hre from "hardhat";

const main = async () => {
  const Mediation = await ethers.getContractFactory("Mediation");
  const mediation = await Mediation.deploy(
    4857,
    "0x30089064d80BF0c08834813e8Fe4c6Abc9ca8D1D"
  );
  await mediation.deployed();

  console.log("Mediation is deployed on ", mediation.address);
  console.log("Sleeping.......");
  await sleep(400000);

  await hre.run("verify:verify", {
    address: mediation.address,
    constructorArguments: [4857, "0x30089064d80BF0c08834813e8Fe4c6Abc9ca8D1D"],
  });
};

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
