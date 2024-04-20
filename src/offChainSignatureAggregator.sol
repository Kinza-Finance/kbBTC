pragma solidity ^0.8.21;


import {Ownable} from '@openzeppelin/access/Ownable.sol';

interface IERC20Mintable {
    function mint(address,uint256) external;
}

contract offChainSignatureAggregator is Ownable(msg.sender) {
    uint256 constant internal maxNumSigner = 8;
    bytes32 internal constant REPORT_HASH = keccak256("Report(address receiver,uint256 amount,uint256 nonce)");
    bytes32 public immutable DOMAIN_SEPARATOR;
    address public immutable wstBTC;

    uint256 public threshold = 1;
    uint256 public nonce;
    mapping(address => bool) public signers;

    event SignerUpdated(address signer, bool right);

    struct Report {
        address receiver;
        uint256 amount;
        uint256 nonce;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(address _wstBTC) public {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("offChainSignatureAggregator"),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
            );
        wstBTC = _wstBTC;
    }

    function mintBTC(Report memory r,  Signature[] memory _rs) external {
        _verifySignature(r, _rs);

        IERC20Mintable(wstBTC).mint(r.receiver, r.amount);
    }

    function _verifySignature(Report memory _report, Signature[] memory _rs) internal {
        require(_rs.length > threshold, "not enough signatures");
        require(_rs.length <= maxNumSigner, "too many signatures");
        require(_report.nonce == nonce + 1, "require sequential execution");
        bytes32 reportHash = reportDigest(_report);
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, reportHash));
        bytes32 r;
        for (uint i = 0; i < _rs.length; i++) {
            Signature memory s = _rs[i];
            address signer = ecrecover(digest, s.v, s.r, s.s);
            require(signers[signer], "unauthorized");
            // signature duplication check using bytes32 r, sufficient.
            require(s.r != r, "non-unique signature");
            r = s.r;
      }
      nonce += 1;
    }
    // what the reporter has to sign off-chain
    function reportDigest(Report memory report) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    REPORT_HASH,
                    report.receiver,
                    report.amount,
                    report.nonce
                )
            );
    }

    function updateThreshold(uint256 _newThreshold) external onlyOwner {
        require(_newThreshold <= maxNumSigner, "max number of signer breached");
        threshold = _newThreshold;
    }

    function setSigners(address[] memory _signers, bool[] memory _rights) external onlyOwner {
        for (uint i = 0; i < _signers.length; i++) {
            signers[_signers[i]] = _rights[i];
            emit SignerUpdated(_signers[i], _rights[i]);
       }
    }
}