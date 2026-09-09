# ---
# schema: "mdd-node-v1"
# id: "functions/mise-bootstrap.fish"
# title: "Mise Infrastructure Bootstrapper"
# layer: "Functions"
# responsibility: "Bootstraps and configures the global tech stack using Mise"
# dependencies: []
# backlinks: ["conf.d/50-utils.fish"]
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["mise", "bootstrap", "infrastructure"]
# ---

function mise-bootstrap --description "Bootstrap the entire mise infrastructure"
    echo "🛠️ Starting Full Mise Infrastructure Setup..."

    # 1. Install mise if missing
    if not type -q mise
        echo "🚀 Mise missing. Bootstrapping environment..."
        if type -q brew
            brew install mise
        else
            curl https://mise.run | sh
        end
    end

    # 2. Configure global mise behaviors
    mise settings set experimental true
    mise settings set trusted_config_paths ~/.config/mise

    # 3. Provision the Global Tech Stack
    echo "📦 Installing Global Tooling (Node 25, Bun, Python 3.14, PNPM)..."
    mise use --global bun@latest node@latest pnpm@latest python@latest rust@latest

    # 4. Cleanup and Validation
    mise cache clear
    mise doctor

    echo "✅ Infrastructure is ready. Please restart your terminal session."
end
