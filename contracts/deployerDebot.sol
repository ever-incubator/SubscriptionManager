pragma ton-solidity >=0.43.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "https://raw.githubusercontent.com/tonlabs/debots/main/Debot.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Terminal/Terminal.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/UserInfo/UserInfo.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/AmountInput/AmountInput.sol";
import "https://raw.githubusercontent.com/tonlabs/debots/main/Sdk.sol";
import "SubsMan.sol";
import "ISubsManCallbacks.sol";
import "SubscriptionService.sol";

interface ISubscription {
    function cancel() external;
}

contract DeployerDebot is Debot, ISubsManCallbacks, IonQuerySubscriptions  {
    bytes m_icon;
    uint128 m_tons;

    address m_subsman;
    uint256 m_ownerKey;
    uint256 m_serviceKey;
    uint32 m_sbHandle;
    address m_wallet;
    address subscrAddr;
    uint128 m_balance;
    TvmCell m_subscriptionServiceImage;
    TvmCell m_subscriptionWalletImage;
    AccData[] s_accounts;
    AccData[] m_accounts;
    address walletAddr;

    function setIcon(bytes icon) public {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();
        m_icon = icon;
    }

    function setSubsman(address addr) public {
        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();
        m_subsman = addr;
    }

    function setSubscriptionWalletCode(TvmCell image) public onlyOwner {
        m_subscriptionWalletImage = image;
    }

    modifier onlyOwner() {
        tvm.accept();
        _;
    }

    function setSubscriptionService(TvmCell image) public onlyOwner {
        m_subscriptionServiceImage = image;
    }

    /// @notice Entry point function for DeBot.
    function start() public override {
        Menu.select("I can manage your subscriptions", "", [
            MenuItem("Deploy new subscription", "", tvm.functionId(menuDeploySubscription)),
            MenuItem("Show my subscriptions", "", tvm.functionId(menuShowSubscription)),
            MenuItem("Manage wallet", "", tvm.functionId(ManageWallet))
        ]);
    }

    function menuDeploySubscription(uint32 index) public {
        index;
        UserInfo.getAccount(tvm.functionId(setDefaultAccount));
        UserInfo.getPublicKey(tvm.functionId(setDefaultPubkey));
        QueryServices();
    }

    function menuServiceKey(uint32 index) public {
        index = index;
        Terminal.input(tvm.functionId(setServiceKey), "Enter public key of service which you want to subscribe to: ", false);
    }
    
    function ManageWallet(uint32 index) public {
        index;
        UserInfo.getAccount(tvm.functionId(setDefaultAccount));
        UserInfo.getPublicKey(tvm.functionId(setDefaultPubkey));
        walletAddr = address(tvm.hash(buildWallet(m_ownerKey)));
        getWalletbalance(m_wallet);
    }

    function menuManageWallet() public {
        Menu.select("Available actions", "", [
            MenuItem("Top up wallet", "", tvm.functionId(menuTopUpWallet)),
            MenuItem("Main menu", "", tvm.functionId(this.start))
        ]);
    }

    function buildWallet(uint256 ownerKey) private view returns (TvmCell image) {
        TvmCell code = m_subscriptionWalletImage.toSlice().loadRef();
        TvmCell newImage = tvm.buildStateInit({
            code: code,
            pubkey: m_ownerKey
        });
        image = newImage;
    }

    function menuTopUpWallet(uint32 index) public {
        index = index;
        TopUpWallet();
        this.start();
    }

    function TopUpWallet() public {
        AmountInput.get(tvm.functionId(setTons), "How many tokens to send?", 9, 1e7, m_balance);
        optional(uint256) pubkey = 0;
        TvmCell m_payload;
        IMultisig(m_wallet).submitTransaction{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: pubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        } (walletAddr, m_tons, false, false, m_payload);
    }

    function setTons(uint128 value) public {
        m_tons = value;
    }

    function _decodeServiceParams(TvmCell data) internal returns (SubscriptionService.ServiceParams) {
        SubscriptionService.ServiceParams svcparams;
        (, , , TvmCell params) = data.toSlice().decode(uint256, uint64, bool, TvmCell);
        (svcparams.to, svcparams.value, svcparams.period, svcparams.name, svcparams.description) = params.toSlice().decode(address, uint128, uint32, string, string);
        return svcparams;
    }

    function _decodeSubscriptionIndexParams(TvmCell data) internal returns (SubscriptionService.ServiceParams) {
        SubscriptionService.ServiceParams svcparams;
        (, , , TvmCell params) = data.toSlice().decode(uint256, uint64, bool, TvmCell);
        (svcparams.to, svcparams.value, svcparams.period, svcparams.myaddress) = params.toSlice().decode(address, uint128, uint32, address);
        return svcparams;
    }

    function printSubscriprionsList(AccData[] accounts) public {
        MenuItem[] items;
        s_accounts = accounts;
        for(uint i = 0; i < accounts.length; i++) {
            items.push(MenuItem(format("{}: {}\nPeriod: {}\nPrice: {}", _decodeServiceParams(accounts[i].data).name, _decodeServiceParams(accounts[i].data).description, _decodeServiceParams(accounts[i].data).period, _decodeServiceParams(accounts[i].data).value), "", tvm.functionId(getSigningBox)));
        }
        items.push(MenuItem("Select subcription service by pubkey", "", tvm.functionId(menuServiceKey)));
        items.push(MenuItem("Main menu", "", tvm.functionId(this.start)));
        Menu.select(format("{} Subscription services has been found. Choose service from the list or enter its pubkey manually:", accounts.length), "", items);
    }

    function buildServiceHelper() public returns (TvmCell) {
        TvmCell code = m_subscriptionServiceImage.toSlice().loadRef();
        return code;      
    }

    function getWalletbalance(address value) public returns (uint128){
        m_wallet = value;
        if (m_wallet == address(0)) {
            Terminal.input(0,"Wallet doesn't exist",false);
        }
        else {
            Sdk.getBalance(tvm.functionId(setBalance), value);
        }
    }

    function setBalance(uint128 nanotokens) public {
        m_balance = nanotokens;
        (uint64 dec, uint64 float) = tokens(m_balance);
        Terminal.print(0,format("Wallet balance is {}.{} tons", dec, float));
        menuManageWallet();
    } 

    function tokens(uint128 nanotokens) private pure returns (uint64, uint64) {
        uint64 decimal = uint64(nanotokens / 1e9);
        uint64 float = uint64(nanotokens - (decimal * 1e9));
        return (decimal, float);
    }
    
    function QueryServices() public {
        TvmCell code = buildServiceHelper();
        Sdk.getAccountsDataByHash(
            tvm.functionId(printSubscriprionsList),
            tvm.hash(code),
            address.makeAddrStd(-1, 0)
        );
    }

    function setDefaultAccount(address value) public {
        Terminal.print(0, format("User account {}", value));
        m_wallet = value;
    }

    function setDefaultPubkey(uint256 value) public {
        Terminal.print(0, format("User public key {:X}", value));
        m_ownerKey = value;
    }

    function setDefaultPubkey2(uint256 value) public {
        Terminal.print(0, format("User public key {:X}", value));
        m_ownerKey = value;
        SubsMan(m_subsman).invokeQuerySubscriptions(m_ownerKey);
    }

    function setSigningBox(uint32 handle) public {
        Terminal.print(0, format("Signing box handle {}", handle));
        m_sbHandle = handle;
    }

    function menuShowSubscription(uint32 index) public {
        index;
        UserInfo.getAccount(tvm.functionId(setDefaultAccount));
        UserInfo.getPublicKey(tvm.functionId(setDefaultPubkey2));
    }

    function _decodeWalletKey(TvmCell data) internal returns (uint256) {
        (uint256 walletKey, ,) = data.toSlice().decode(uint256, uint64, bool);
        return walletKey;        
    }

    function setServiceKey(string value) public {
        if (!_parseServiceKey(value)) return;
        getSigningBox(0);
    }

    function _decodeServiceKey(TvmCell data) internal returns (uint256) {
        Terminal.print(0, "_decodeServiceKey...");
        (uint256 svcKey, ,) = data.toSlice().decode(uint256, uint64, bool);
        return svcKey;
    }

    function getSigningBox(uint32 index) public {
        uint256[] keys;
        if (m_serviceKey == 0) {
            m_serviceKey = _decodeServiceKey(s_accounts[index].data);
        }
        if (m_sbHandle == 0) {
            SigningBoxInput.get(
                tvm.functionId(setSigningBoxHandle),
                "Choose your keys to sign transactions from multisig.",
                keys
            );
        } else {
            setSigningBoxHandle(m_sbHandle);
        }
    }

    function setSigningBoxHandle(uint32 handle) public {
        m_sbHandle = handle;
        subsmanInvokeDeploy();
    }

    function setSigningBoxHandle2(uint32 handle) public {
        m_sbHandle = handle;
        invokeCancel();
    }

    function invokeCancel() public {
        optional(uint256) pubkey = m_ownerKey;
        optional(uint32) sbhandle = m_sbHandle;
        // add .await when abi 2.1 will be supported in debots
        ISubscription(subscrAddr).cancel{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            signBoxHandle: sbhandle,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        }();       
    }

    function subsmanInvokeDeploy() public view {
        TvmBuilder args;
        args.store(uint(228));
        SubsMan(m_subsman).invokeDeploySubscription(
            m_ownerKey,
            m_serviceKey,
            m_wallet,
            m_sbHandle,
            args.toCell()
        );
    }

    function onSubscriptionDeploy(Status status, address addr) external override{
        uint8 stat = uint8(status);
        if (status == Status.Success) {
            Terminal.print(0, format("Subscription successfully deployed:\n{}", addr));
        } else {
            Terminal.print(0, format("Subscription deploy failed. Error status {}", stat));
        }

        this.start();
    }
    function onQuerySubscriptions(AccData[] accounts) external override{
        MenuItem[] items;
        m_accounts = accounts;
        Terminal.print(0, format("You have {} subscriptions", accounts.length));
        for(uint i = 0; i < accounts.length; i++) {
            items.push(MenuItem(format("Name: {}\nDescription: {}\nPeriod: {}\nPrice: {}", _decodeSubscriptionIndexParams(accounts[i].data).name, _decodeSubscriptionIndexParams(accounts[i].data).description, _decodeSubscriptionIndexParams(accounts[i].data).period, _decodeSubscriptionIndexParams(accounts[i].data).value), "", tvm.functionId(menuManageSubscription)));
        }
        items.push(MenuItem("Select your subcription by subscription service key", "", tvm.functionId(menuServiceKey)) );
        items.push(MenuItem("Main menu", "", tvm.functionId(this.start)));
        Menu.select(format("{} your subscriptions has been found. To manage it choose subscription from the list or enter its address manually:", accounts.length), "", items);
    }

    function menuManageSubscription(uint32 index) public {
        UserInfo.getAccount(tvm.functionId(setDefaultAccount));
        UserInfo.getPublicKey(tvm.functionId(setDefaultPubkey));
        subscrAddr = _decodeSubscriptionIndexParams(m_accounts[index].data).myaddress;
        Terminal.print(0, format("Subscription address: {}", subscrAddr));
        Menu.select("Manage your subscription status", "", [
            MenuItem("Cancel this subscription", "", tvm.functionId(cancelSubscription)),
            MenuItem("Main menu", "", tvm.functionId(this.start))
        ]);
    }

    function cancelSubscription(uint32 index) public {
        index;
        uint256[] keys;
        if (m_sbHandle == 0) {
            SigningBoxInput.get(
                tvm.functionId(setSigningBoxHandle2),
                "Choose your keys to sign transactions from multisig.",
                keys
            );
        }
        else {
            invokeCancel();
        }
    }

    function onSuccess() public {
        Terminal.print(0, format("You successfully unsubscribed from {}", subscrAddr));
        this.start();
    }

    function onError(uint32 sdkError, uint32 exitCode) public {
        // TODO: handle errors
        Terminal.print(0, format("Error: sdk code = {}, exit code = {}", sdkError, exitCode));
    }

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string caption, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "Subscription Deployer";
        version = "0.2.0";
        publisher = "INTONNATION";
        caption = "Subscription Deployment";
        author = "INTONNATION";
        support = address.makeAddrStd(0, 0);
        hello = "Hello, I am a Subscription Deployer DeBot.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, UserInfo.ID ];
    }

    //
    // Private Helpers
    //

    function _parseServiceKey(string value) private returns (bool) {
        (uint256 key, bool res) = stoi("0x" + value);
        if (!res) {
            Terminal.print(tvm.functionId(Debot.start), "Invalid public key.");
            return res;
        }
        m_serviceKey = key;
        return res;
    }

}
