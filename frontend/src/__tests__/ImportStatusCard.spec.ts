import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import ImportStatusCard from '@/components/imports/ImportStatusCard.vue'
import { baseImport } from './fixtures'

describe('ImportStatusCard', () => {
  it('shows import warnings, e.g. a missing My Rating column', () => {
    const wrapper = mount(ImportStatusCard, {
      props: {
        import: {
          ...baseImport,
          status: 'completed',
          stats: {
            rows_total: 1,
            warnings: ['Column "My Rating" was not found, so it wasn\'t imported.'],
          },
        },
      },
    })
    expect(wrapper.get('[data-testid="import-warnings"]').text()).toContain('My Rating')
  })

  it('shows no warnings block when there are none', () => {
    const wrapper = mount(ImportStatusCard, {
      props: {
        import: { ...baseImport, status: 'completed', stats: { rows_total: 1, warnings: [] } },
      },
    })
    expect(wrapper.find('[data-testid="import-warnings"]').exists()).toBe(false)
  })
})
