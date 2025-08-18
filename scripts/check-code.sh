#!/bin/bash

# Script para formatação e verificação de código Go
# Autor: K8s Addon Team
# Uso: ./check-code.sh [--fix|--check|--all]

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar se comando existe
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Comando '$1' não encontrado. Instalando..."
        return 1
    fi
    return 0
}

# Instalar ferramentas necessárias
install_tools() {
    log_info "Verificando e instalando ferramentas necessárias..."
    
    # goimports
    if ! check_command goimports; then
        log_info "Instalando goimports..."
        go install golang.org/x/tools/cmd/goimports@latest
    fi
    
    # golangci-lint
    if ! check_command golangci-lint; then
        log_info "Instalando golangci-lint..."
        go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    fi
    
    # gosec (security check) - opcional
    if ! check_command gosec; then
        log_warning "gosec não encontrado (verificação de segurança será pulada)"
        log_info "Para instalar: go install github.com/securecodewarrior/gosec/cmd/gosec@latest"
    fi
    
    log_success "Todas as ferramentas estão disponíveis"
}

# Formatação de código
format_code() {
    log_info "Formatando código Go..."
    
    log_info "Executando go fmt..."
    go fmt ./...
    
    log_info "Organizando imports com goimports..."
    goimports -w .
    
    log_success "Código formatado com sucesso"
}

# Verificação estática
static_check() {
    log_info "Executando verificações estáticas..."
    
    local has_errors=0
    
    # go vet
    log_info "Executando go vet..."
    if ! go vet ./...; then
        log_error "go vet encontrou problemas"
        has_errors=1
    else
        log_success "go vet passou"
    fi
    
    # golangci-lint
    log_info "Executando golangci-lint..."
    if ! golangci-lint run --timeout=5m; then
        log_error "golangci-lint encontrou problemas"
        has_errors=1
    else
        log_success "golangci-lint passou"
    fi
    
    return $has_errors
}

# Verificação de segurança
security_check() {
    log_info "Executando verificação de segurança..."
    
    if ! check_command gosec; then
        log_warning "gosec não disponível, pulando verificação de segurança"
        return 0
    fi
    
    if ! gosec ./...; then
        log_warning "gosec encontrou possíveis problemas de segurança"
        return 1
    else
        log_success "Verificação de segurança passou"
        return 0
    fi
}

# Verificação de build
build_check() {
    log_info "Verificando se o código compila..."
    
    if ! go build ./...; then
        log_error "Falha na compilação"
        return 1
    else
        log_success "Compilação bem-sucedida"
        return 0
    fi
}

# Verificação de testes
test_check() {
    log_info "Executando testes..."
    
    if ! go test ./... -v; then
        log_error "Alguns testes falharam"
        return 1
    else
        log_success "Todos os testes passaram"
        return 0
    fi
}

# Verificação de dependencies
deps_check() {
    log_info "Verificando dependências..."
    
    log_info "Executando go mod tidy..."
    go mod tidy
    
    log_info "Verificando dependências não utilizadas..."
    if ! go mod verify; then
        log_error "Problemas com dependências"
        return 1
    fi
    
    log_success "Dependências verificadas"
    return 0
}

# Verificação completa
full_check() {
    log_info "Executando verificação completa..."
    
    local total_errors=0
    
    deps_check || ((total_errors++))
    format_code
    static_check || ((total_errors++))
    security_check || ((total_errors++))
    build_check || ((total_errors++))
    
    # Só executar testes se houver arquivos de teste
    if find . -name "*_test.go" -type f | grep -q .; then
        test_check || ((total_errors++))
    else
        log_warning "Nenhum arquivo de teste encontrado"
    fi
    
    if [ $total_errors -eq 0 ]; then
        log_success "Todas as verificações passaram! ✅"
        return 0
    else
        log_error "Encontrados $total_errors problemas"
        return 1
    fi
}

# Verificação rápida (sem testes)
quick_check() {
    log_info "Executando verificação rápida..."
    
    local total_errors=0
    
    format_code
    static_check || ((total_errors++))
    build_check || ((total_errors++))
    
    if [ $total_errors -eq 0 ]; then
        log_success "Verificação rápida passou! ✅"
        return 0
    else
        log_error "Encontrados $total_errors problemas"
        return 1
    fi
}

# Só formatação
fix_only() {
    log_info "Executando apenas formatação..."
    deps_check
    format_code
    log_success "Formatação concluída! ✅"
}

# Exibir estatísticas do código
show_stats() {
    log_info "Estatísticas do código:"
    echo
    echo "📁 Arquivos Go:"
    find . -name "*.go" -not -path "./vendor/*" | wc -l
    echo
    echo "📏 Linhas de código:"
    find . -name "*.go" -not -path "./vendor/*" -exec wc -l {} + | tail -1
    echo
    echo "📦 Pacotes:"
    go list ./... | wc -l
    echo
    echo "🔧 Dependências diretas:"
    go list -m all | grep -v "$(go list -m)" | wc -l
}

# Ajuda
show_help() {
    echo "Uso: $0 [OPÇÃO]"
    echo
    echo "OPÇÕES:"
    echo "  --fix, -f        Apenas formatar código"
    echo "  --check, -c      Verificação rápida (sem testes)"
    echo "  --all, -a        Verificação completa (com testes)"
    echo "  --security, -s   Apenas verificação de segurança"
    echo "  --stats          Mostrar estatísticas do código"
    echo "  --install        Instalar ferramentas necessárias"
    echo "  --help, -h       Mostrar esta ajuda"
    echo
    echo "Sem argumentos: executa verificação rápida"
}

# Função principal
main() {
    echo "🔍 K8s Addon - Verificador de Código"
    echo "====================================="
    echo
    
    # Verificar se estamos no diretório correto
    if [ ! -f "go.mod" ]; then
        log_error "go.mod não encontrado. Execute este script no diretório raiz do projeto."
        exit 1
    fi
    
    case "${1:-}" in
        --fix|-f)
            install_tools
            fix_only
            ;;
        --check|-c)
            install_tools
            quick_check
            ;;
        --all|-a)
            install_tools
            full_check
            ;;
        --security|-s)
            install_tools
            security_check
            ;;
        --stats)
            show_stats
            ;;
        --install)
            install_tools
            ;;
        --help|-h)
            show_help
            ;;
        "")
            install_tools
            quick_check
            ;;
        *)
            log_error "Opção inválida: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Executar função principal
main "$@" 