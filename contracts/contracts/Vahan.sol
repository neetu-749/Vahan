// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract ahan {
    enum Role {
        manufacturer,
        retailer,
        customer,
        not_registered
    }

    enum Stage {
        manufactured,
        released,
        sold
    }

    struct Vehicle {
        uint256 id;
        string name;
        uint256 price;
        string ipfs_hash;
        Stage stage;
        address manufacturer;
        uint256 total_retailers;
        address customer;
        address currentOwner;
    }

    struct Manufacturer {
        address id;
        string name;
        uint256 total_vehicles;
    }

    struct Retailer {
        address id;
        string name;
        uint256 total_vehicles;
    }

    struct Customer {
        address id;
        string name;
        uint256 total_orders;
    }

    uint256 public total_vehicles;
    Vehicle[] public vehicles;
    mapping(address => Manufacturer) public manufacturers;
    mapping(address => Retailer) public retailers;
    mapping(address => Customer) public customers;
    mapping(uint256 => address[]) public Vehicle_Retailers;

    mapping(address => uint256[]) public manufacturer_inventory;
    mapping(address => uint256[]) public retailer_inventory;
    mapping(address => uint256[]) public customer_orders;

    address[] address_array;

    event Vahan_deployed(string _message);
    event Vehicle_Added(
        uint256 _VehicleId,
        address _manufacturerAddress,
        uint256 _time
    );
    event Vehicle_Released(
        uint256 _vehicleId,
        address _manufacturerAddress,
        address _retailerAddress,
        uint256 _time
    );
    event Vehicle_Sold(
        uint256 _vehicleId,
        address _retailerAddress,
        address _customerAddress,
        uint256 _time
    );

    constructor() {
        total_vehicles = 0;
        emit Vahan_deployed("Vahan has been deployed");
    }

    modifier isManufacturer(address _manufacturerAddress) {
        require(
            manufacturers[_manufacturerAddress].id != address(0x0),
            "Only manufacturers can perform this action"
        );
        _;
    }

    modifier isRetailer(address _retailerAddress) {
        require(
            retailers[_retailerAddress].id != address(0x0),
            "Only retailers can perform this action"
        );
        _;
    }

    modifier isCustomer(address _customerAddress) {
        require(
            customers[_customerAddress].id != address(0x0),
            "Only customers can perform this action"
        );
        _;
    }

    function removeElement(uint256 index, uint256[] storage array)
        internal
        returns (uint256[] storage)
    {
        for (uint256 i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
        return array;
    }

    function getVehicles() public view returns (Vehicle[] memory) {
        return vehicles;
    }

    function addManufacturer(string memory _name)
        public
        payable
        returns (Manufacturer memory)
    {
        require(
            bytes(manufacturers[msg.sender].name).length == 0,
            "This address is already registered as manufacturer"
        );

        Manufacturer memory _manufacturer;
        _manufacturer.id = msg.sender;
        _manufacturer.name = _name;
        _manufacturer.total_vehicles = 0;

        manufacturers[msg.sender] = _manufacturer;

        return _manufacturer;
    }

    function addRetailer(string memory _name)
        public
        payable
        returns (Retailer memory)
    {
        require(
            bytes(retailers[msg.sender].name).length == 0,
            "This address is already registered as retailer"
        );

        Retailer memory _retailer;
        _retailer.id = msg.sender;
        _retailer.name = _name;
        _retailer.total_vehicles = 0;

        retailers[msg.sender] = _retailer;

        return _retailer;
    }

    function addCustomer(string memory _name)
        public
        payable
        returns (Customer memory)
    {
        require(
            bytes(customers[msg.sender].name).length == 0,
            "This address is already registered as retailer"
        );

        Customer memory _customer;
        _customer.id = msg.sender;
        _customer.name = _name;

        customers[msg.sender] = _customer;

        return _customer;
    }

    function addVehicle(
        string memory _name,
        uint256 _price,
        string memory _ipfs_hash,
        uint256 _time
    ) public payable isManufacturer(msg.sender) returns (Vehicle memory) {
        require(
            manufacturers[msg.sender].id != address(0),
            "Only manufacturers can add vehicle"
        );

        //get the manufacturer
        Manufacturer memory _manufacturer = manufacturers[msg.sender];

        //create the vehicle
        Vehicle memory _vehicle;
        _vehicle.id = total_vehicles;
        _vehicle.name = _name;
        _vehicle.price = _price;
        _vehicle.ipfs_hash = _ipfs_hash;
        _vehicle.manufacturer = _manufacturer.id;
        _vehicle.stage = Stage.manufactured;
        _vehicle.total_retailers = 0;
        _vehicle.currentOwner = msg.sender;

        //add the vehicle to records
        vehicles.push(_vehicle);
        total_vehicles += 1;

        //add the vehicle to the manufacturer inventory records
        manufacturer_inventory[msg.sender].push(_vehicle.id);
        _manufacturer.total_vehicles += 1;
        manufacturers[msg.sender] = _manufacturer;

        //Add into proper mappings
        Vehicle_Retailers[_vehicle.id] = address_array;

        emit Vehicle_Added(_vehicle.id, msg.sender, _time);

        return _vehicle;
    }

    function releaseVehicle(uint256 _vehicleId, uint256 _time)
        public
        payable
        isRetailer(msg.sender)
        returns (Vehicle memory)
    {
        require(_vehicleId < total_vehicles, "Vehicle does not exist");

        //Get the vehicle
        Vehicle memory _vehicle = vehicles[_vehicleId];

        //check if the vehicle has already been released or manufactured
        require(
            _vehicle.stage == Stage.manufactured,
            "Vehicle has been released or sold"
        );

        //Shift ownership from manufacturer to retailer
        Vehicle_Retailers[_vehicleId].push(msg.sender);
        _vehicle.total_retailers++;
        _vehicle.stage = Stage.released;
        _vehicle.currentOwner = msg.sender;

        //Remove the element from the inventory of manufacturer and update count
        Manufacturer memory _manufacturer = manufacturers[
            _vehicle.manufacturer
        ];
        for (uint256 i = 0; i < _manufacturer.total_vehicles; i++) {
            if (
                manufacturer_inventory[_vehicle.manufacturer][i] == _vehicleId
            ) {
                manufacturer_inventory[_vehicle.manufacturer] = removeElement(
                    i,
                    manufacturer_inventory[_vehicle.manufacturer]
                );
                // delete manufacturer_inventory[_vehicle.manufacturer][i];
                break;
            }
        }
        _manufacturer.total_vehicles -= 1;
        manufacturers[_vehicle.manufacturer] = _manufacturer;

        //Add the vehicle to retailer's inventory and update count
        retailer_inventory[msg.sender].push(_vehicle.id);
        Retailer memory _retailer = retailers[msg.sender];
        _retailer.total_vehicles += 1;
        retailers[msg.sender] = _retailer;

        //save the updated vehicle details
        vehicles[_vehicleId] = _vehicle;

        emit Vehicle_Released(
            _vehicleId,
            _vehicle.manufacturer,
            msg.sender,
            _time
        );

        return _vehicle;
    }

    function buyVehicle(uint256 _vehicleId, uint256 _time)
        public
        payable
        isCustomer(msg.sender)
        returns (Vehicle memory)
    {
        require(_vehicleId < total_vehicles, "Vehicle does not exist");

        //Get the vehicle
        Vehicle memory _vehicle = vehicles[_vehicleId];

        //check if the vehicle has already been released or manufactured
        require(
            _vehicle.stage == Stage.released,
            "Vehicle has not been released or has been already sold"
        );

        //Get the details of the retailer who is selling
        address _retailerId = Vehicle_Retailers[_vehicle.id][
            _vehicle.total_retailers - 1
        ];
        Retailer memory _retailer = retailers[_retailerId];

        //Get the details of the customer
        Customer memory _customer = customers[msg.sender];

        //Shift ownership from retailer to customer
        _vehicle.stage = Stage.sold;
        _vehicle.customer = _customer.id;
        _vehicle.currentOwner = msg.sender;

        //Remove the element from the inventory of retailer and update count
        address _current_retailer_address = Vehicle_Retailers[_vehicleId][
            Vehicle_Retailers[_vehicleId].length - 1
        ];
        Retailer memory _current_retailer = retailers[
            _current_retailer_address
        ];
        for (uint256 i = 0; i < _current_retailer.total_vehicles; i++) {
            if (
                retailer_inventory[_current_retailer_address][i] == _vehicleId
            ) {
                retailer_inventory[_current_retailer_address] = removeElement(
                    i,
                    retailer_inventory[_current_retailer_address]
                );
                // delete retailer_inventory[_current_retailer_address][i];
                break;
            }
        }
        _current_retailer.total_vehicles -= 1;
        retailers[_current_retailer_address] = _current_retailer;

        //Add the vehicle to customer's orders and update count
        customer_orders[msg.sender].push(_vehicle.id);
        _customer.total_orders += 1;
        customers[msg.sender] = _customer;

        //save the updated vehicle details
        vehicles[_vehicletId] = _vehicle;

        emit Vehicle_Sold(_vehicleId, _retailer.id, msg.sender, _time);

        return _vehicle;
    }

    function getManufacturerDetails(address _manufacturerId)
        public
        view
        returns (Manufacturer memory)
    {
        Manufacturer memory _manufacturer = manufacturers[_manufacturerId];
        return _manufacturer;
    }

    function getManufacturerInventory(address _manufacturerId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _vehicle_ids = manufacturer_inventory[_manufacturerId];
        return _vehicle_ids;
    }

    function getRetailerDetails(address _retailerId)
        public
        view
        returns (Retailer memory)
    {
        Retailer memory _retailer = retailers[_retailerId];
        return _retailer;
    }

    function getRetailerInventory(address _retailerId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _vehicle_ids = retailer_inventory[_retailerId];
        return _vehicle_ids;
    }

    function getCustomerDetails(address _customerId)
        public
        view
        returns (Customer memory)
    {
        Customer memory _customer = customers[_customerId];
        return _customer;
    }

    function getCustomerOrders(address _customerId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _vehicle_ids = customer_orders[_customerId];
        return _vehicle_ids;
    }

    function getVehicleDetails(uint256 _vehicleId)
        public
        view
        returns (
            Vehicle memory,
            Retailer[] memory,
            Manufacturer memory,
            Customer memory
        )
    {
        //Get the vehicle
        Vehicle memory _vehicle = vehicles[_vehicleId];

        //Get all the retailers addresses
        address[] memory _retailer_addresses = Vehicle_Retailers[_vehicleId];

        //Initialize an empty reailters array
        Retailer[] memory _retailers = new Retailer[](_vehicle.total_retailers);

        //Get the manufacturer
        Manufacturer memory _manufacturer = getManufacturerDetails(
            _vehicle.manufacturer
        );

        //Get the customer
        Customer memory _customer = getCustomerDetails(_vehicle.customer);

        //Push all the retailers in the _retailers array
        for (uint256 i = 0; i < _retailer_addresses.length; i++) {
            _retailers[i] = getRetailerDetails(_retailer_addresses[i]);
        }
        return (_vehicle, _retailers, _manufacturer, _customer);
    }

    function getCurrentStatus(uint256 _vehicleId)
        public
        view
        returns (
            Stage,
            address,
            Manufacturer memory,
            Customer memory,
            Retailer memory
        )
    {
        //Initilize an empty address for owner
        address _owner_address;

        //Get vehicle details
        Vehicle memory _vehicle = vehicles[_vehicleId];

        //Get vehicle stage
        Stage _stage = _vehicle.stage;

        //Instantiate each user
        Manufacturer memory _manufacturer;
        Customer memory _customer;
        Retailer memory _retailer;

        //Check for each stage
        if (_stage == Stage.manufactured) {
            _owner_address = _vehicle.manufacturer;
            _manufacturer = getManufacturerDetails(_owner_address);
        } else if (_stage == Stage.sold) {
            _owner_address = _vehicle.customer;
            _customer = getCustomerDetails(_owner_address);
        } else {
            _owner_address = Vehicle_Retailers[_vehicleId][
                _vehicle.total_retailers - 1
            ];
            _retailer = getRetailerDetails(_owner_address);
        }
        return (_stage, _owner_address, _manufacturer, _customer, _retailer);
    }

    function getUserType(address _user) public view returns (Role) {
        if (manufacturers[_user].id != address(0x0)) return Role.manufacturer;

        if (retailers[_user].id != address(0x0)) return Role.retailer;

        if (customers[_user].id != address(0x0)) return Role.customer;

        return Role.not_registered;
    }
}
