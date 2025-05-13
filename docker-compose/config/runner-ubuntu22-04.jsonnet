local common = import 'common.libsonnet';

{
  buildDirectoryPath: '/worker/build',
  global: common.global + {
    diagnosticsHttpServer: {
      httpServers: [{
        listenAddresses: [':80'],
        authenticationPolicy: { allow: {} },
      }],
      enablePrometheus: true,
      enablePprof: true,
      enableActiveSpans: true,
    },
    logging: {
      level: 'DEBUG',
      format: 'json',
    },
  },
  grpcServers: [{
    listenPaths: ['/worker/runner'],
    authenticationPolicy: { allow: {} },
  }],
}
