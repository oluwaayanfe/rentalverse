# NFT Rental Protocol

A decentralized NFT rental protocol built on the Stacks blockchain that enables secure peer-to-peer NFT rentals with collateral protection.

## Features

- List NFTs for rent with customizable terms
- Rent NFTs by providing STX collateral 
- Automatic collateral protection
- Dispute resolution system
- Extensible rental periods
- Admin controls for protocol updates

## Smart Contract Functions

### Core Functions

- `list-nft`: List an NFT for rental with specified terms
- `rent-nft`: Rent a listed NFT by providing collateral
- `return-nft`: Return a rented NFT to the owner
- `extend-rental`: Extend an active rental period
- `claim-collateral`: Claim collateral for unreturned NFTs
- `flag-dispute`: Flag a rental for dispute resolution

### Management Functions

- `set-admin`: Update protocol admin
- `update-listing`: Modify rental listing terms
- `delist-nft`: Remove an NFT listing
- `get-listing`: Get rental listing details

## Setup & Deployment

1. Clone the repository
2. Install dependencies:
```bash
npm install
```
3. Deploy contract:
```bash
clarinet deploy
```

## Testing

Run the test suite:
```bash
clarinet test
```

## Security

The protocol implements several security measures:
- Collateral protection
- Input validation
- Access controls
- Dispute resolution system

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Open pull request

## Contact

For questions or support, please open an issue on GitHub.
