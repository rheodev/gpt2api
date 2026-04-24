export interface BrandParts {
  brand: string
  repo: string
  repoLabel: string
  sep: string
}

export function brandParts(): BrandParts {
  return {
    brand: 'GPT2API',
    repo: 'github.com/432539/gpt2api',
    repoLabel: '开源仓库：',
    sep: '·',
  }
}
