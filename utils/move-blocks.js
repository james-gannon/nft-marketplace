/**
 * A script to manully mine blocks with Hardhat.
 * This is to be used as a utilitiy that can be imported into other scripts.
 */

const { network } = require("hardhat")

function sleep(timeInMs) {
    // In order to wait for some time, we must use promises.
    return new Promise((resolve) => setTimeout(resolve, timeInMs))
}

async function moveBlocks(amount, sleepAmount = 0) {
    // Have it mimic blockchain behavior by "sleeping" every time a block is moved.
    console.log("Moving blocks...")
    for (let index = 0; index < amount; index++) {
        await network.provider.request({
            method: "evm_mine",
            params: [],
        })
        if (sleepAmount) {
            console.log(`Sleeping for ${sleepAmount}`)
            await sleep(sleepAmount)
        }
    }
}

module.exports = {
    moveBlocks,
    sleep,
}
