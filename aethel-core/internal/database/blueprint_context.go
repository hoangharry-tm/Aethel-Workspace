package database

import (
	"bytes"
	"fmt"
	"text/template"

	"aethel-core/internal/blueprint"
)

// BlueprintContext holds the values injected into SQL migration templates.
type BlueprintContext struct {
	Schema string
	tables map[string]string
	enums  map[string]string
}

func NewBlueprintContext(cfg *blueprint.DatabaseConfig) *BlueprintContext {
	tables := cfg.Schema.NameAliases
	if tables == nil {
		tables = make(map[string]string)
	}
	enums := cfg.Schema.EnumAliases
	if enums == nil {
		enums = make(map[string]string)
	}
	return &BlueprintContext{
		Schema: cfg.Schema.DefaultSchema,
		tables: tables,
		enums:  enums,
	}
}

// FuncMap returns the template.FuncMap that exposes T and E for SQL templates.
func (b *BlueprintContext) FuncMap() template.FuncMap {
	return template.FuncMap{
		"T": func(canonical string) string {
			if alias, ok := b.tables[canonical]; ok && alias != "" {
				return alias
			}
			return canonical
		},
		"E": func(canonical string) string {
			if alias, ok := b.enums[canonical]; ok && alias != "" {
				return alias
			}
			return canonical
		},
	}
}

func renderMigration(content []byte, ctx *BlueprintContext) (string, error) {
	tmpl, err := template.New("migration").
		Funcs(ctx.FuncMap()).
		Parse(string(content))
	if err != nil {
		return "", fmt.Errorf("parse template: %w", err)
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, ctx); err != nil {
		return "", fmt.Errorf("render template: %w", err)
	}
	return buf.String(), nil
}
