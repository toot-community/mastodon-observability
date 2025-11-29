// Base configuration for the Mastodon observability stack.
// Holds shared knobs so environments can override defaults without touching rule logic.
{
  observabilityNamespace: 'mastodon-observability',
  supportedNamespaces: ['microblog-network', 'toot-community'],
  alertNamespaces: ['toot-community'],

  ingress: {
    rpsWindow: '5m',
    latencyWindow: '5m',
    latencyHostExcludeRegex: 'streaming\\\\..*',
    apdex: {
      satisfiedSeconds: 0.1,
      toleratingSeconds: 0.5,  // approx 4T
      minRequestRate: 0.1,  // drop to "no data" below this rps to avoid noisy zeros on idle hosts
      appHosts: ['microblog.network', 'toot.community', 'www.microblog.network', 'www.toot.community'],
      staticHosts: ['static.microblog.network', 'static.toot.community'],
      appIngresses: ['varnish-for-app', 'mastodon-web'],
      staticIngresses: ['varnish-for-static'],
    },
  },

  requestClasses: {
    user_facing: {
      controllers: [
        'home',
        'statuses',
        'notifications',
        'notifications',  // keep explicit for special actions like unread_count
        'tags',
        'tag',
        'public',
        'timelines',
        'accounts',
        'relationships',
        'follow_requests',
        'followers',
        'following',
        'favourites',
        'bookmarks',
        'media',
        'explore',
        'collections',
        'search',
        'intents',
        'announcements',
        'suggestions',
        'oembed',
        'filters',
        'markers',
        'reblogs',
        'reblogged_by_accounts',
        'follower_accounts',
        'following_accounts',
        'link',
        'lists',
        'media_proxy',
        'registrations',
        'health',
        'replies',
        'lookup',
        'policies',
        'credentials',
        'familiar_followers',
        'blocks',
        'application',
        'mutes',
        'domain_blocks',
        'custom_emojis',
        'manifests',
        'conversations',
        'subscriptions',
      ],
      actions: ['index', 'show', 'create', 'update', 'destroy', 'context', 'stream', 'other', 'new', 'unread_count', 'activity', 'raise_not_found'],
    },
    federation: {
      controllers: [
        'inboxes',
        'outboxes',
        'instance_actors',
        'nodeinfo',
        'instances',
        'webfinger',
        'well_known',
        'follows',
        'followers',
        'push',
        'pull',
        'relay',
        'outbox',
        'federation_statuses',
        'activitypub',
        'remote_follow',
      ],
      actions: ['show', 'index', 'create', 'deliver', 'accept', 'reject', 'followers', 'outbox'],
    },
  },

  slo: {
    availabilityTarget: 0.995,
    windows: {
      '5m': '5m',
      '30m': '30m',
      '1h': '1h',
      '6h': '6h',
      '30d': '30d',
    },
    latency: {
      satisfiedSeconds: 0.1,
      toleratingSeconds: 0.5,
      frustratedSeconds: 1.0,
    },
  },

  sidekiq: {
    queues: ['default', 'push', 'ingress', 'mailers', 'pull', 'scheduler', 'fasp'],
    latencyWarningSeconds: 30,
    latencyCriticalSeconds: 120,
    latencyWarningWindow: '5m',
    latencyCriticalWindow: '10m',
    deadQueue: {
      warningGrowthRatio: 0.01,
      criticalGrowthRatio: 0.02,
      evaluationWindow: '1h',
    },
  },

  streaming: {
    zeroClientWindow: '10m',
    eventloopLagWarningSeconds: 0.1,
    lagWindow: '10m',
    baselineWindow: '30m',
    drop: {
      warningRatio: 0.5,  // 50% drop vs recent baseline
      criticalRatio: 0.8,  // 80% drop vs recent baseline
      window: '10m',
    },
  },

  dashboard: {
    defaultTimeRange: '12h',
  },

  grafana: {
    datasource: {
      type: 'prometheus',
      uid: 'victoriametrics',
    },
    logsDatasource: 'VictoriaLogs',
  },

  withDefaultNamespace(ns):: self { defaultNamespace: ns },
}
