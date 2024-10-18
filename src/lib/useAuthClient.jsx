import { AuthClient } from "@dfinity/auth-client";
import React, { createContext, useContext, useEffect, useState } from "react";
import { AccountIdentifier } from "@dfinity/ledger-icp";
import { Actor, HttpAgent } from "@dfinity/agent";
import { AssetManager } from '@dfinity/assets';
import { createActor } from "@/declarations/just-try-backend";

const AuthContext = createContext();

const defaultOptions = {
  /**
   *  @type {import("@dfinity/auth-client").AuthClientCreateOptions}
   */
  createOptions: {
    // idleOptions: {
    //   // Set to true if you do not want idle functionality
    //   disableIdle: true,
    // },
    idleOptions: {
      idleTimeout: 1000 * 60 * 30, // set to 30 minutes
      disableDefaultIdleCallback: true, // disable the default reload behavior
    },
  },
  /**
   * @type {import("@dfinity/auth-client").AuthClientLoginOptions}
   */
  loginOptions: {
    identityProvider: 
      process.env.DFX_NETWORK === "ic"
        ? "https://identity.ic0.app/#authorize"
        : `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:${process.env.REPLICA_PORT}/#authorize`,
  },
};

export const useAuthClient = (options = defaultOptions) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authClient, setAuthClient] = useState(null);
  const [identity, setIdentity] = useState(null);
  const [principal, setPrincipal] = useState(null);
  const [accountId, setAccountId] = useState(null);
  const [agent, setAgent] = useState(null);
  const [assetManager, setAssetManager] = useState(null);
  const [justTryBackend, setJustTryBackend] = useState(null);

  const isLocal = !window.location.host.endsWith('ic0.app');

  useEffect(() => {

    console.log(`[useAuthClient][useEffect] Init auth client.`);
    // Initialize AuthClient
    AuthClient.create(options.createOptions).then((client) => {
      setAuthClient(client);
    });
  }, []);

  function toHexString(byteArray) {
    return Array.from(byteArray, function (byte) {
      return ("0" + (byte & 0xff).toString(16)).slice(-2);
    }).join("");
  }

  const login = () => {
    return new Promise(async(resolve, reject) => {
      if (authClient.isAuthenticated() && ((await authClient.getIdentity().getPrincipal().isAnonymous()) === false)) {

        const principal = authClient.getIdentity().getPrincipal();
        console.log(`[useAuthClient][login] Already authenticated with Pricipal Id `, principal.toText());
        const lagent = await setupAgent(authClient);
        setupAssetManager(lagent);
        await updateClient(authClient);
        resolve(authClient);        
      } else {
        console.log(`[useAuthClient][login] Not authenticate, perform login.`);
        authClient.login({
          ...options.loginOptions,
          onError: (error) => {
            console.log(`[useAuthClient][login] Error:`, error);

          },
          onSuccess: async () => {
            console.log(`[useAuthClient][login] Login success.`);
            const lagent = await setupAgent(authClient);
            setupAssetManager(lagent);

            await updateClient(authClient);
            resolve(authClient);
          }
        })
      }
    })
  }

  const updateClient = async (client) => {

    console.log(`[useAuthClient][updateClient] ...`);
    const isAuthenticated = await client.isAuthenticated();
    setIsAuthenticated(isAuthenticated);

    const identity = client.getIdentity();
    setIdentity(identity);

    const principal = identity.getPrincipal();
    setPrincipal(principal);

    const accountId = AccountIdentifier.fromPrincipal({ principal });
    setAccountId(toHexString(accountId.bytes));

    setAuthClient(client);

    let accountIdString = toHexString(accountId.bytes);

    const host = process.env.DFX_NETWORK !== 'ic' ? 'http://127.0.0.1:4943' : 'https://ic0.app';

    console.log(`[useAuthClient][updateClient] host:`, host);

    const lagent = new HttpAgent({
      host, identity,
    });

    // Fetch root key for certificate validation during development
    if (process.env.DFX_NETWORK !== "ic") {
      // Will throw error when
      console.log(`[useAuthClient][updateClient] Running in local, fetch root key`);
      await lagent.fetchRootKey().catch((err) => {
        console.log(`[useAuthClient][updateClient] Error (fetchRootKey): `, err);
      });
    }

    const jtBackend = createActor(
      process.env.CANISTER_ID_JUST_TRY_BACKEND,
      {
        agent: lagent,
      }
    );    

    setJustTryBackend(jtBackend);

  }

  const logout = async () => {
    await authClient?.logout();
    await updateClient(authClient);
    setIsAuthenticated(false);
  }

  const setupAgent = async (client) => {
    const identity = client.getIdentity();

    const lagent = new HttpAgent({
      host: (process.env.DFX_NETWORK !== "ic") ? `http://127.0.0.1:${process.env.REPLICA_PORT}` : 'https://ic0.app', identity,
    });

    // Fetch root key for certificate validation during development
    if (process.env.DFX_NETWORK !== "ic") {
      // Will throw error when
      console.log(`[useAuthClient][setupAgent] Running in local, fetch root key`);
      await lagent.fetchRootKey().catch((err) => {
        console.log(`[useAuthClient][setupAgent] Error (fetchRootKey): `, err);
      });
    }

    setAgent(lagent);
    return lagent;
  }

  const setupAssetManager = (agent) => {
    const canisterId = process.env.CANISTER_ID_JUST_TRY_FRONTEND;
    console.log(`[useAuthClient][setupAssetManager] Asset Canister Id:`, canisterId)    
    const assetManager = new AssetManager({canisterId, agent});
    setAssetManager(assetManager);

    return assetManager;
  }

  return {
    isAuthenticated,
    login,
    logout,
    updateClient,
    authClient,
    identity,
    principal,
    accountId,
    agent,
    setupAgent,
    assetManager,
    setupAssetManager,
    justTryBackend
  }
}

export const AuthProvider = ({ children }) => {
  const auth = useAuthClient();

  return <AuthContext.Provider value={auth}>{children}</AuthContext.Provider>;
};

export const useAuth = () => useContext(AuthContext);