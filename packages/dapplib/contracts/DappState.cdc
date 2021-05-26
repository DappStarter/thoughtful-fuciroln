pub contract DappState {


  // Declare the NFT resource type
    pub resource NFT {
        // The unique ID that differentiates each NFT
        pub let id: UInt64

        // Initialize both fields in the init function
        init(initID: UInt64) {
            self.id = initID
        }
    }

    // We define this interface purely as a way to allow users
    // to create public, restricted references to their NFT Collection.
    // They would use this to only expose the deposit, getIDs,
    // and idExists fields in their Collection
    pub resource interface NFTReceiver {

        pub fun deposit(token: @NFT) 

        pub fun getIDs(): [UInt64]

        pub fun idExists(id: UInt64): Bool
    }

    // The definition of the Collection resource that
    // holds the NFTs that a user owns
    pub resource Collection: NFTReceiver {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NFT}

        // Initialize the NFTs field to an empty collection
        init () {
            self.ownedNFTs <- {}
        }

        // withdraw 
        //
        // Function that removes an NFT from the collection 
        // and moves it to the calling context
        pub fun withdraw(withdrawID: UInt64): @NFT {
            // If the NFT isn't found, the transaction panics and reverts
            let token <- self.ownedNFTs.remove(key: withdrawID)!

            return <-token
        }

        // deposit 
        //
        // Function that takes a NFT as an argument and 
        // adds it to the collections dictionary
        pub fun deposit(token: @NFT) {
            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[token.id] <- token
            destroy oldToken
        }

        // idExists checks to see if a NFT 
        // with the given ID exists in the collection
        pub fun idExists(id: UInt64): Bool {
            return self.ownedNFTs[id] != nil
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // creates a new empty Collection resource and returns it 
    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    // NFTMinter
    //
    // Resource that would be owned by an admin or by a smart contract 
    // that allows them to mint new NFTs when needed
    pub resource NFTMinter {

        // the ID that is used to mint NFTs
        // it is onlt incremented so that NFT ids remain
        // unique. It also keeps track of the total number of NFTs
        // in existence
        pub var idCount: UInt64

        init() {
            self.idCount = 1
        }

        // mintNFT 
        //
        // Function that mints a new NFT with a new ID
        // and deposits it in the recipients collection 
        // using their collection reference
        pub fun mintNFT(recipient: &AnyResource{NFTReceiver}) {

            // create a new NFT
            var newNFT <- create NFT(initID: self.idCount)
            
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            // change the id so that each ID is unique
            self.idCount = self.idCount + UInt64(1)
        }
    }

    // https://play.onflow.org/8a1987ad-f5b3-4548-a460-56faef700221
    /*
    *   In this example, we want to create a simple approval voting contract 
    *   where a polling place issues ballots to addresses. 
    *   
    *   The run a vote, the Admin deploys the smart contract,
    *   then initializes the proposals 
    *   using the initialize_proposals.cdc transaction.
    *   The array of proposals cannot be modified after it has been initialized.
    *
    *   Then they will give ballots to users by 
    *   using the issue_ballot.cdc transaction.
    *
    *   Every user with a ballot is allowed to approve any number of proposals. 
    *   A user can choose their votes and cast them 
    *   with the cast_vote.cdc transaction.
    * 
    */

    //list of proposals to be approved
    pub var proposals: [String]

    // number of votes per proposal
    pub let votes: {Int: Int}

    // This is the resource that is issued to users.
    // When a user gets a Ballot object, they call the `vote` function
    // to include their votes, and then cast it in the smart contract 
    // using the `cast` function to have their vote included in the polling
    pub resource Ballot {

        // array of all the proposals 
        pub let proposals: [String]

        // corresponds to an array index in proposals after a vote
        pub var choices: {Int: Bool}

        init() {
            self.proposals = DappState.proposals
            self.choices = {}
            
            // Set each choice to false
            var i = 0
            while i < self.proposals.length {
                self.choices[i] = false
                i = i + 1
            }
        }

        // modifies the ballot
        // to indicate which proposals it is voting for
        pub fun vote(proposal: Int) {
            pre {
                self.proposals[proposal] != nil: "Cannot vote for a proposal that doesn't exist"
            }
            self.choices[proposal] = true
        }
    }

    // Resource that the Administrator of the vote controls to
    // initialize the proposals and to pass out ballot resources to voters
    pub resource Administrator {

        // function to initialize all the proposals for the voting
        pub fun initializeProposals(_ proposals: [String]) {
            pre {
                DappState.proposals.length == 0: "Proposals can only be initialized once"
                proposals.length > 0: "Cannot initialize with no proposals"
            }
            DappState.proposals = proposals

            // Set each tally of votes to zero
            var i = 0
            while i < proposals.length {
                DappState.votes[i] = 0
                i = i + 1
            }
        }

        // The admin calls this function to create a new Ballot
        // that can be transferred to another user
        pub fun issueBallot(): @Ballot {
            return <-create Ballot()
        }
    }

    // A user moves their ballot to this function in the contract where 
    // its votes are tallied and the ballot is destroyed
    pub fun cast(ballot: @Ballot) {
        var index = 0
        // look through the ballot
        while index < self.proposals.length {
            if ballot.choices[index]! {
                // tally the vote if it is approved
                self.votes[index] = self.votes[index]! + 1
            }
            index = index + 1;
        }
        // Destroy the ballot because it has been tallied
        destroy ballot
    }

    pub fun proposalList(): [String] {
        return self.proposals;
    }



    init() {


		// store an empty NFT Collection in account storage
        self.account.save(<-self.createEmptyCollection(), to: /storage/NFTCollection)

        // publish a reference to the Collection in storage
        self.account.link<&{NFTReceiver}>(/public/NFTReceiver, target: /storage/NFTCollection)

        // store a minter resource in account storage
        self.account.save(<-create NFTMinter(), to: /storage/NFTMinter)


    // initializes the contract by setting the proposals and votes to empty 
    // and creating a new Admin resource to put in storage
    self.proposals = []
    self.votes = {}
    self.account.save(<-create Administrator(), to: /storage/VotingAdmin)



    }
}