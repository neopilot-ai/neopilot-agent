# NeoPilot Agent

A Neovim plugin that provides AI-powered code completion and assistance.

## Features

- Intelligent code completion
- Context-aware suggestions
- Support for multiple languages
- Extensible architecture

## Installation

### Prerequisites

- Neovim 0.8.0 or higher
- [Optional] Tree-sitter for better code understanding

### Using Packer.nvim

```lua
use {
  'your-username/neopilot-agent',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    require('neopilot').setup {
      -- Configuration options here
    }
  end
}
```

### Using Lazy.nvim

```lua
{
  'your-username/neopilot-agent',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  config = true, -- or your custom config
}
```

## Configuration

```lua
require('neopilot').setup {
  debug = false,
  -- Add your configuration here
}
```

## Usage

### Basic Commands

- `:NeoPilotComplete` - Trigger code completion
- `:NeoPilotStatus` - Show status

### Key Mappings

```lua
-- Example key mappings
vim.keymap.set('n', '<leader>nc', ':NeoPilotComplete<CR>', { silent = true })
```

## Development

### Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   make deps
   ```

### Running Tests

```bash
make test          # Run all tests
make test-coverage # Run tests with coverage
make lint          # Run linter
make fmt           # Format code
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linter
5. Submit a pull request

## License

MIT