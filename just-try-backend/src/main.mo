import Icrc1Ledger "canister:icrc1_ledger_canister";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Blob "mo:base/Blob";
// import Array "mo:base/Array";
// import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Types "Types";


shared (install) actor class JustTry(someone : Principal) =
  this { // Bind the optional `this` argument (any name will do)

  type TransferArgs = {
    amount : Nat;
    toAccount : Icrc1Ledger.Account;
  };

  // Return the principal identifier of the wallet canister that installed this
  // canister.
  public query func installer() : async Principal {
    return install.caller;
  };

  // Return the principal identifier that was provided as an installation
  // argument to this canister.
  public query func argument() : async Principal {
    return someone;
  };

  // Return the principal identifier of the caller of this method.
  public shared (message) func whoami() : async Principal {
    return message.caller;
  };

  // Return the principal identifier of this canister.
  public func id() : async Principal {
    return await whoami();
  };

  // Return the principal identifier of this canister via the optional `this` binding.
  // This is much quicker than `id()` above, since it avoids the latency of `await whoami()`.
  public func idQuick() : async Principal {
    return Principal.fromActor(this);
  };

  public func wallet_balance() : async Nat {
    return Cycles.balance();
  };  

  public shared func transfer(args : TransferArgs) : async Result.Result<Icrc1Ledger.BlockIndex, Text> {
    Debug.print(
      "Transferring "
      # debug_show (args.amount)
      # " tokens to account"
      # debug_show (args.toAccount)
    );

    let transferArgs : Icrc1Ledger.TransferArg = {
      // can be used to distinguish between transactions
      memo = null;
      // the amount we want to transfer
      amount = args.amount;
      // we want to transfer tokens from the default subaccount of the canister
      from_subaccount = null;
      // if not specified, the default fee for the canister is used
      fee = null;
      // the account we want to transfer tokens to
      to = args.toAccount;
      // a timestamp indicating when the transaction was created by the caller; if it is not specified by the caller then this is set to the current ICP time
      created_at_time = null;
    };

    try {
      // initiate the transfer
      let transferResult = await Icrc1Ledger.icrc1_transfer(transferArgs);

      // check if the transfer was successfull
      switch (transferResult) {
        case (#Err(transferError)) {
          return #err("Couldn't transfer funds:\n" # debug_show (transferError));
        };
        case (#Ok(blockIndex)) { return #ok blockIndex };
      };
    } catch (error : Error) {
      // catch any errors that might occur during the transfer
      return #err("Reject message: " # Error.message(error));
    };
  };
 
//This method sends a GET request to a URL with a free API we can test.
//This method returns Coinbase data on the exchange rate between USD and ICP 
//for a certain day.
//The API response looks like this:
//  [
//     [
//         1682978460, <-- start timestamp
//         5.714, <-- lowest price during time range 
//         5.718, <-- highest price during range
//         5.714, <-- price at open
//         5.714, <-- price at close
//         243.5678 <-- volume of ICP traded
//     ],
// ]

  //function to transform the response
  public query func transform(raw : Types.TransformArgs) : async Types.CanisterHttpResponsePayload {
      let transformed : Types.CanisterHttpResponsePayload = {
          status = raw.response.status;
          body = raw.response.body;
          headers = [
              {
                  name = "Content-Security-Policy";
                  value = "default-src 'self'";
              },
              { name = "Referrer-Policy"; value = "strict-origin" },
              { name = "Permissions-Policy"; value = "geolocation=(self)" },
              {
                  name = "Strict-Transport-Security";
                  value = "max-age=63072000";
              },
              { name = "X-Frame-Options"; value = "DENY" },
              { name = "X-Content-Type-Options"; value = "nosniff" },
          ];
      };
      transformed;
  };
  
  public func get_postman_echo() : async Text {

    //1. DECLARE IC MANAGEMENT CANISTER
    //We need this so we can use it to make the HTTP request
    let ic : Types.IC = actor ("aaaaa-aa");

    //2. SETUP ARGUMENTS FOR HTTP GET request

    // 2.1 Setup the URL and its query parameters
    //let ONE_MINUTE : Nat64 = 60;
    //let start_timestamp : Types.Timestamp = 1682978460; //May 1, 2023 22:01:00 GMT
    //let end_timestamp : Types.Timestamp = 1682978520;//May 1, 2023 22:02:00 GMT
    //let host : Text = "api.pro.coinbase.com";
    //let url = "https://" # host # "/products/ICP-USD/candles?start=" # Nat64.toText(start_timestamp) # "&end=" # Nat64.toText(start_timestamp) # "&granularity=" # Nat64.toText(ONE_MINUTE);
    
    let host = "postman-echo.com";
    let url = "https://" # host # "/get?name=Just_Try";
    // 2.2 prepare headers for the system http_request call
    let request_headers = [
        { name = "Host"; value = host # ":443" },
        { name = "User-Agent"; value = "Just Try Backend" },
    ];

    // 2.2.1 Transform context
    let transform_context : Types.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    // 2.3 The HTTP request
    let http_request : Types.HttpRequestArgs = {
        url = url;
        max_response_bytes = null; //optional for request
        headers = request_headers;
        body = null; //optional for request
        method = #get;
        transform = ?transform_context;
    };

    //3. ADD CYCLES TO PAY FOR HTTP REQUEST

    //The IC specification spec says, "Cycles to pay for the call must be explicitly transferred with the call"
    //IC management canister will make the HTTP request so it needs cycles
    //See: https://internetcomputer.org/docs/current/motoko/main/cycles
    
    //The way Cycles.add() works is that it adds those cycles to the next asynchronous call
    //"Function add(amount) indicates the additional amount of cycles to be transferred in the next remote call"
    //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request
    Cycles.add(230_949_972_000);
    
    //4. MAKE HTTPS REQUEST AND WAIT FOR RESPONSE
    //Since the cycles were added above, we can just call the IC management canister with HTTPS outcalls below
    let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);
    
    //5. DECODE THE RESPONSE

    //As per the type declarations in `src/Types.mo`, the BODY in the HTTP response 
    //comes back as [Nat8s] (e.g. [2, 5, 12, 11, 23]). Type signature:
    
    //public type HttpResponsePayload = {
    //     status : Nat;
    //     headers : [HttpHeader];
    //     body : [Nat8];
    // };

    //We need to decode that [Nat8] array that is the body into readable text. 
    //To do this, we:
    //  1. Convert the [Nat8] into a Blob
    //  2. Use Blob.decodeUtf8() method to convert the Blob to a ?Text optional 
    //  3. We use a switch to explicitly call out both cases of decoding the Blob into ?Text
    let response_body: Blob = Blob.fromArray(http_response.body);
    let decoded_text: Text = switch (Text.decodeUtf8(response_body)) {
        case (null) { "No value returned" };
        case (?y) { y };
    };

    //6. RETURN RESPONSE OF THE BODY
    //The API response will looks like this:

    // ("[[1682978460,5.714,5.718,5.714,5.714,243.5678]]")

    //Which can be formatted as this
    //  [
    //     [
    //         1682978460, <-- start/timestamp
    //         5.714, <-- low
    //         5.718, <-- high
    //         5.714, <-- open
    //         5.714, <-- close
    //         243.5678 <-- volume
    //     ],
    // ]
    decoded_text
  };

};
