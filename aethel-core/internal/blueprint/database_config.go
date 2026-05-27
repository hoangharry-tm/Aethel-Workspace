package blueprint

type DatabaseConfig struct {
	Metadata               Metadata                     `yaml:"metadata"`
	GlobalDatabaseDefaults GlobalDatabaseDefaults       `yaml:"global_database_defaults"`
	Environments           map[string]EnvironmentConfig `yaml:"environments"`
	Schema                 SchemaConfig                 `yaml:"schema"`
	Partitioning           map[string]PartitionConfig   `yaml:"partitioning"`
	Extensions             ExtensionConfig              `yaml:"extensions"`
	Performance            PerformanceConfig            `yaml:"performance"`
}

type Metadata struct {
	Version          string `yaml:"version"`
	EngineTarget     string `yaml:"engine_target"`
	StrictValidation bool   `yaml:"strict_validation"`
}

type GlobalDatabaseDefaults struct {
	Dialect  string          `yaml:"dialect"`
	Encoding string          `yaml:"encoding"`
	Timezone string          `yaml:"timezone"`
	Logging  LoggingDefaults `yaml:"logging"`
}

type LoggingDefaults struct {
	LogQueries            bool   `yaml:"log_queries"`
	SlowQueryThresholdMs  int    `yaml:"slow_query_threshold_ms"`
	LogLevel              string `yaml:"log_level"`
}

type EnvironmentConfig struct {
	Connection ConnectionConfig `yaml:"connection"`
	Pooling    PoolingConfig    `yaml:"pooling"`
	Migrations MigrationConfig  `yaml:"migrations"`
}

type ConnectionConfig struct {
	Host                string `yaml:"host"`
	Port                int    `yaml:"port"`
	Database            string `yaml:"database"`
	User                string `yaml:"user"`
	SSLMode             string `yaml:"ssl_mode"`
	SSLRootCertPath     string `yaml:"ssl_root_cert_path"`
	ConnectionStringEnv string `yaml:"connection_string_env"`
}

type PoolingConfig struct {
	MaxOpenConnections           int `yaml:"max_open_connections"`
	MaxIdleConnections           int `yaml:"max_idle_connections"`
	ConnectionMaxLifetimeMinutes int `yaml:"connection_max_lifetime_minutes"`
	ConnectionMaxIdleTimeMinutes int `yaml:"connection_max_idle_time_minutes"`
}

type MigrationConfig struct {
	Directory          string `yaml:"directory"`
	AutoRunOnStartup   bool   `yaml:"auto_run_on_startup"`
	TableName          string `yaml:"table_name"`
	LockTimeoutSeconds int    `yaml:"lock_timeout_seconds"`
}

type SchemaConfig struct {
	DefaultSchema string            `yaml:"default_schema"`
	NameAliases   map[string]string `yaml:"name_aliases"`
	EnumAliases   map[string]string `yaml:"enum_aliases"`
}

type PartitionConfig struct {
	Type            string          `yaml:"type"`
	Column          string          `yaml:"column"`
	Interval        string          `yaml:"interval"`
	RetentionPolicy RetentionPolicy `yaml:"retention_policy"`
}

type RetentionPolicy struct {
	Enabled       bool `yaml:"enabled"`
	RetainMonths  int  `yaml:"retain_months"`
}

type ExtensionConfig struct {
	Required []string `yaml:"required"`
	Optional []string `yaml:"optional"`
}

type PerformanceConfig struct {
	StatementTimeoutMs           int `yaml:"statement_timeout_ms"`
	IdleInTransactionTimeoutMs   int `yaml:"idle_in_transaction_timeout_ms"`
	LockTimeoutMs                int `yaml:"lock_timeout_ms"`
}
