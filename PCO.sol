
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/access/AccessControl.sol"; 
import "@openzeppelin/contracts/utils/math/SafeMath.sol"; 
import "@openzeppelin/contracts/utils/Address.sol"; 
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol"; 
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PCO is AccessControl, Ownable, ReentrancyGuard { 
  using SafeMath for uint256; 
  using Address for address;

  // Estructura para almacenar información de un token 
  struct Token { 
    address owner; 
    string name; 
  }

  // Mapping para llevar un registro de los tokens 
  mapping (bytes32 => uint256) private tokenRegistry;

  // Mapping para llevar un registro de la propiedad de los tokens
  mapping (bytes32 => TokenOwnership) private tokenOwners;

  // Estructura para almacenar información sobre la propiedad de un token
  struct TokenOwnership {
    address owner;
    uint256 id;
    bool active;
  }

  // Mapping para llevar un conteo de los tokens de un propietario 
  mapping (address => uint256) private ownerTokenCount;

  // Variables para almacenar la tasa de comisión, la billetera de comisiones y el número máximo de transacciones por segundo 
  uint256 private commissionRate; 
  address private commissionWallet; 
  uint256 private maxTransactionsPerSecond;

  // Variables para controlar el estado del contrato y la lista blanca de direcciones autorizadas 
  bool private contractPaused; 
  bytes32 private salt; 
  EnumerableSet private whiteList;

  // Enumeración para manejar errores 
  enum Errors { 
    CONTRACT_PAUSED, 
    TOKEN_REGISTERED, 
    MAX_LIMIT, 
    NOT_AUTHORIZED, 
    NOT_OWNER, 
    INVALID_COMMISSION, 
    INVALID_ADDRESS, 
    NAME_TOO_LONG,
    DUPLICATE_NAME
  }

  // Eventos para registrar acciones importantes en el contrato 
  event TokenRegistered(bytes32 indexed hash, uint256 tokenId, address indexed from); 
  event TokenDeleted(bytes32 indexed hash, uint256 tokenId, address indexed from);
  event OwnershipTransferred(bytes32 indexed hash, uint256 tokenId, address indexed from, address indexed to); 
  event CommissionRateUpdated(uint256 rate); 
  event WalletAddressUpdated(address wallet);
  event MaxTransactionsUpdated(uint256 maxTransactions);
  event ContractPaused(); 
   event ContractResumed(); 
  event WhiteListupdated(address[] addresses, bool status);
event MaxTransactionsPerSecondUpdated(uint256 rate);

// Función para registrar un nuevo token
function registerToken(string memory _name, bytes32 hash) public {
require(!contractPaused, "CONTRACT_PAUSED: Contract is paused.");
require(!tokenRegistry[hash], "TOKEN_REGISTERED: Token already registered.");
require(ownerTokenCount[msg.sender] <= maxTransactionsPerSecond, "MAX_LIMIT: Maximum limit reached.");
// Verifica si la dirección enviadora está en la lista blanca 
bool isAuthorized = whiteList.exists(msg.sender); 
require(isAuthorized, "NOT_AUTHORIZED: Not authorized.");

// Verifica si el nombre es demasiado largo 
require(bytes(_name).length <= 100, "NAME_TOO_LONG: Name is too long.");

// Verifica si el nombre es único 
for (uint256 i = 0; i < tokenOwners.length; i++) {
  if (tokenOwners[i].active && tokenOwners[i].id == hash) {
    require(tokenOwners[i].owner == msg.sender, "DUPLICATE_NAME: Name is already taken by another owner.");
  }
}

// Crea una nueva entrada en el registro de tokens 
uint256 tokenId = tokenOwners.length;
tokenRegistry[hash] = tokenId;
ownerTokenCount[msg.sender]++;
tokenOwners[tokenId] = TokenOwnership(msg.sender, hash, true);

// Emite el evento TokenRegistered 
emit TokenRegistered(hash, tokenId, msg.sender);
}

// Función para transferir la propiedad de un token
function transferTokenOwnership(bytes32 hash, address to) public {
require(!contractPaused, "CONTRACT_PAUSED: Contract is paused.");
require(tokenRegistry[hash], "TOKEN_REGISTERED: Token not registered.");

// Verifica si la dirección enviadora es el propietario actual del token 
uint256 tokenId = tokenRegistry[hash];
require(tokenOwners[tokenId].owner == msg.sender, "NOT_OWNER: You are not the owner.");

// Verifica si la dirección destinataria es una dirección válida 
require(to != address(0), "INVALID_ADDRESS: Invalid address.");

// Verifica si la dirección destinataria está en la lista blanca 
bool isAuthorized = whiteList.exists(to); 
require(isAuthorized, "NOT_AUTHORIZED: Not authorized.");

// Actualiza la propiedad del token 
ownerTokenCount[tokenOwners[tokenId].owner]--;
ownerTokenCount[to]++;
tokenOwners[tokenId].owner = to;

// Emite el evento OwnershipTransferred 
emit OwnershipTransferred(hash, tokenId, msg.sender, to);
}

// Método para establecer la tasa de comisión
function setCommissionRate(uint256 rate) public onlyOwner {
// Verifica si la tasa de comisión es válida
require(rate <= 100, "INVALID_COMMISSION: Invalid commission rate.");
commissionRate = rate;

// Emite el evento CommissionRateUpdated
emit CommissionRateUpdated(rate);
}

// Método para establecer la dirección de la billetera de comisiones
function setCommissionWallet(address wallet) public onlyOwner {
// Verifica si la dirección de la billetera es válida
require(wallet != address(0), "INVALID_ADDRESS: Invalid wallet address.");
commissionWallet = wallet;

// Emite el evento WalletAddressUpdated
emit WalletAddressUpdated(wallet);
}

// Método para establecer el número máximo de transacciones por segundo
function setMaxTransactionsPerSecond(uint256 maxTransactions) public onlyOwner {
maxTransactionsPerSecond = maxTransactions;

// Emite el evento MaxTransactionsUpdated
emit MaxTransactionsUpdated(maxTransactions);
}

// Método para pausar el contrato
function pause() public onlyOwner {
contractPaused = true;

// Emite el evento ContractPaused
emit ContractPaused();
}

// Método para reanudar el contrato
function resume() public onlyOwner {
contractPaused = false;
}

// Método para agregar una dirección a la lista blanca
function addToWhiteList(address to) public onlyOwner {
// Verifica si la dirección es válida
require(to != address(0), "INVALID_ADDRESS: Invalid address.");
whiteList.add(to);
}

// Método para quitar una dirección de la lista blanca
function removeFromWhiteList(address to) public onlyOwner {
whiteList.remove(to);
}
// Método para actualizar la tasa de comisión
function updateCommissionRate(uint256 rate) public onlyOwner {
commissionRate = rate;
emit CommissionRateUpdated(rate);
}

// Método para actualizar la billetera de comisiones
function updateCommissionWallet(address wallet) public onlyOwner {
commissionWallet = wallet;
emit WalletAddressUpdated(wallet);
}

// Método para actualizar el número máximo de transacciones por segundo
function updateMaxTransactions(uint256 maxTransactions) public onlyOwner {
maxTransactionsPerSecond = maxTransactions;
emit MaxTransactionsUpdated(maxTransactions);
}

// Método para pausar el contrato
function pause() public onlyOwner {
contractPaused = true;
emit ContractPaused();
}

// Método para reanudar el contrato
function unpause() public onlyOwner {
contractPaused = false;
}
// Método para verificar si el contrato está pausado o no
function isPaused() public view returns (bool) {
return contractPaused;
}

// Modificador de acceso solo propietario
modifier onlyOwner() {
require(msg.sender == owner, "ONLY_OWNER: Only owner can perform this action.");
_;
}
// Modificador para verificar si el contrato está en pausa
modifier whenNotPaused() {
require(!contractPaused, "CONTRACT_PAUSED: Contract is paused.");
_;
}

// Modificador para verificar el número de transacciones por segundo
modifier withinLimit() {
require(block.timestamp >= lastProcessedBlock + blockInterval, "LIMIT_EXCEEDED: Transactions per second limit exceeded.");
lastProcessedBlock = block.timestamp;
_;
}

// Modificador para combinar los modificadores onlyOwner y whenNotPaused
modifier onlyOwnerAndWhenNotPaused() {
require(msg.sender == owner && !contractPaused, "ONLY_OWNER_WHEN_NOT_PAUSED: Only owner can perform this action when contract is not paused.");
_;
}

// Modificador para combinar los modificadores whenNotPaused y withinLimit
modifier whenNotPausedAndWithinLimit() {
require(!contractPaused && block.timestamp >= lastProcessedBlock + blockInterval, "NOT_PAUSED_WITHIN_LIMIT: Contract must not be paused and must be within the transactions per second limit.");
lastProcessedBlock = block.timestamp;
_;
}
// Función para transferir la propiedad de un token
function transferOwnership(bytes32 hash, address to) public {
require(!contractPaused, "CONTRACT_PAUSED: Contract is paused.");
require(tokenRegistry[hash] != 0, "TOKEN_REGISTERED: Token not registered.");
require(tokenOwners[tokenRegistry[hash]].owner == msg.sender, "NOT_OWNER: Sender is not the owner.");
require(to != address(0), "INVALID_ADDRESS: Invalid address.");

// Aumenta el conteo de tokens del destinatario
ownerTokenCount[to]++;

// Transfiere la propiedad del token
tokenOwners[tokenRegistry[hash]].owner = to;

// Emite el evento OwnershipTransferred
emit OwnershipTransferred(hash, tokenRegistry[hash], msg.sender, to);
}

// Función para actualizar la tasa de comisión
function updateCommissionRate(uint256 rate) public onlyOwner {
require(rate <= 100, "INVALID_COMMISSION: Invalid commission rate.");
commissionRate = rate;
emit CommissionRateUpdated(rate);
}

// Función para actualizar la dirección de la billetera de comisiones
function updateWalletAddress(address wallet) public onlyOwner {
require(wallet != address(0), "INVALID_ADDRESS: Invalid address.");
commissionWallet = wallet;
emit WalletAddressUpdated(wallet);
}

// Función para actualizar el número máximo de transacciones por segundo
function updateMaxTransactions(uint256 maxTransactions) public onlyOwner {
maxTransactionsPerSecond = maxTransactions;
emit MaxTransactionsUpdated(maxTransactions);
}

// Función para pausar el contrato
function pause() public onlyOwner {
contractPaused = true;
emit ContractPaused();
}

// Función para reanudar el contrato
function resume() public onlyOwner {
contractPaused = false;
emit ContractResumed();
}

// Función para actualizar la lista blanca de direcciones autorizadas
function updateWhiteList(address[] memory addresses, bool status) public onlyOwner {
if (status) {
whiteList.addArray(addresses);
} else {
whiteList.removeArray(addresses);
}
emit WhiteListUpdated(addresses, status);
}

// Función para obtener la información de un token dado su hash
function getToken(bytes32 hash) public view returns (string memory, address) {
require(tokenRegistry[hash] != 0, "TOKEN_REGISTERED: Token not registered.");
return (tokenOwners[tokenRegistry[hash]].name, tokenOwners[tokenRegistry[hash]].owner);
}

// Función para obtener el número de tokens registrados por un propietario dado
function getTokenCount(address owner) public view returns (uint256) {
return ownerTokenCount[owner];
}
}

