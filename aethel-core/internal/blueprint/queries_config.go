package blueprint

type QueriesConfig struct {
	Metadata            Metadata                       `yaml:"metadata"`
	GlobalQueryDefaults GlobalQueryDefaults            `yaml:"global_query_defaults"`
	Queries             map[string]map[string]Query    `yaml:"queries"`
}

type GlobalQueryDefaults struct {
	TimeoutMs              int  `yaml:"timeout_ms"`
	EnableQueryPlanCaching bool `yaml:"enable_query_plan_caching"`
	MaxRowsPerPage         int  `yaml:"max_rows_per_page"`
}

type Query struct {
	Statement          string   `yaml:"statement"`
	Params             []string `yaml:"params"`
	TimeoutMs          int      `yaml:"timeout_ms"`
	CacheTTLSeconds    int      `yaml:"cache_ttl_seconds"`
	RequiredPermission string   `yaml:"required_permission"`
	Description        string   `yaml:"description"`
}
