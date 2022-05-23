/* eslint-disable prettier/prettier */
/* eslint-disable import/no-duplicates */
import { ethers } from "hardhat";
import hre from "hardhat";

const main = async () => {
  const Mediation = await ethers.getContractFactory("Mediation");
  const mediation = await Mediation.deploy(
    4857,
    "0xF456aEa643B3836CddA504F14c5A945C356468aB"
  );
  await mediation.deployed();

  console.log("Mediation is deployed on ", mediation.address);
  console.log("Sleeping.......");
  await sleep(400000);

  await hre.run("verify:verify", {
    address: mediation.address,
    constructorArguments: [4857, "0xF456aEa643B3836CddA504F14c5A945C356468aB"],
  });
};

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
