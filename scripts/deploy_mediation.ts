/* eslint-disable prettier/prettier */
/* eslint-disable import/no-duplicates */
import { ethers } from "hardhat";
import hre from "hardhat";

const main = async () => {
  const Mediation = await ethers.getContractFactory("Mediation");
  const mediation = await Mediation.deploy(
    4857,
    "0xf63158EC0AE9Ae232C54350EcCF2C5C5FC194470"
  );
  await mediation.deployed();

  console.log("Mediation is deployed on ", mediation.address);
  console.log("Sleeping.......");
  await sleep(400000);

  await hre.run("verify:verify", {
    address: mediation.address,
    constructorArguments: [4857, "0xf63158EC0AE9Ae232C54350EcCF2C5C5FC194470"],
  });
};

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
