export const idlFactory = ({ IDL }) => {
  const JustTry = IDL.Service({
    'argument' : IDL.Func([], [IDL.Principal], ['query']),
    'id' : IDL.Func([], [IDL.Principal], []),
    'idQuick' : IDL.Func([], [IDL.Principal], []),
    'installer' : IDL.Func([], [IDL.Principal], ['query']),
    'whoami' : IDL.Func([], [IDL.Principal], []),
  });
  return JustTry;
};
export const init = ({ IDL }) => { return [IDL.Principal]; };
