// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC1155 is IERC165 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);
    
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}

contract PencilCollections is IERC1155 {
    mapping (uint256 => mapping(address => uint256)) private _balanceOf;
    mapping (address => mapping(address => bool)) private _operatorApprovals;
    string public _uri;
    
    uint256 public constant NATRAJ = 0; 
    uint256 public constant APSARA = 1;
    
    uint256[] listIds = [NATRAJ, APSARA];
    
    constructor (string memory uri_) {
        _setURI(uri_);
    }
    
    function balanceOf(address account, uint256 id) public override view returns (uint256) {
        require(account != address(0), 'Address cannot be zero');
        
        return _balanceOf[id][account];
    }
    
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) public override view returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }
    
    function setApprovalForAll(address operator, bool approved) public override {
        require(operator != address(0), 'Operator address cannot be 0');
        
        require(msg.sender != operator, 'Caller cannot be the operator');
        
        _operatorApprovals[msg.sender][operator] = approved;
        
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function isApprovedForAll(address account, address operator) public override view returns (bool) {
        require(account != address(0), 'Owner address cannot be 0');
        
        require(operator != address(0), 'Operator address cannot be 0');
        
        return _operatorApprovals[account][operator];
    }
    
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public override {
        require(from != address(0), "ERC1155: transfer from the zero address");
        
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = msg.sender;
        
        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

        uint256 fromBalance = _balanceOf[id][from];
        
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        
        _balanceOf[id][from] = fromBalance - amount;
        _balanceOf[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);
    }
    
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes memory data) public override {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        
        require(from != address(0), "ERC1155: transfer from the zero address");
        
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = msg.sender;
        
        require( (from == msg.sender || isApprovedForAll(from, msg.sender)), "ERC721: transfer caller is not owner nor approved");
        
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balanceOf[id][from];
            
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            
            _balanceOf[id][from] = fromBalance - amount;
            _balanceOf[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);
    }
    
    function _mint(address account, uint256 id, uint256 amount, bytes memory data) public virtual {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = msg.sender;
        
        _beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);

        _balanceOf[id][account] += amount;
        
        emit TransferSingle(operator, address(0), account, id, amount);
    }
    
    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = msg.sender;
        
        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint i = 0; i < ids.length; i++) {
            _balanceOf[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);
    }
    
    function _burn(address account, uint256 id, uint256 amount) public virtual {
        require(account != address(0), "ERC1155: burn from the zero address");

        address operator = msg.sender;
        
        _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

        uint256 accountBalance = _balanceOf[id][account];
        require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
        _balanceOf[id][account] = accountBalance - amount;

        emit TransferSingle(operator, account, address(0), id, amount);
    }
    
    function _burnBatch(address account, uint256[] memory ids, uint256[] memory amounts) public virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = msg.sender;
        
        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balanceOf[id][account];
            require(accountBalance >= amount, "ERC1155: burn amount exceeds balance");
            _balanceOf[id][account] = accountBalance - amount;
        }

        emit TransferBatch(operator, account, address(0), ids, amounts);
    }
    
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        virtual
    { }

    
    function uri(uint256) public view virtual returns (string memory) {
        return _uri;
    }
    
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId;
    }
    
    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}
