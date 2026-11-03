import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, RouterLinkStub } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import * as importsApi from '@/api/imports'
import { ApiError } from '@/api/client'
import CsvDropzone from '@/components/imports/CsvDropzone.vue'
import { useImportsStore } from '@/stores/imports'
import OnboardingView from '@/views/OnboardingView.vue'
import { baseImport } from './fixtures'

vi.mock('@/api/imports')
vi.mock('@/api/auth')

const file = new File(['a'], 'a.csv')

async function uploadFailing(err: ApiError) {
  vi.mocked(importsApi.create).mockRejectedValue(err)
  const wrapper = mount(OnboardingView, { global: { stubs: { RouterLink: RouterLinkStub } } })
  await flushPromises()
  wrapper.getComponent(CsvDropzone).vm.$emit('select', file)
  await flushPromises()
  return wrapper
}

describe('OnboardingView', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    vi.mocked(importsApi.list).mockResolvedValue([])
    setActivePinia(createPinia())
  })

  it('maps invalid_goodreads_export and includes the server message', async () => {
    const w = await uploadFailing(new ApiError(422, 'invalid_goodreads_export', 'Missing: Title'))
    expect(w.get('[role="alert"]').text()).toContain(
      "That file doesn't look like a Goodreads export.",
    )
    expect(w.get('[role="alert"]').text()).toContain('Missing: Title')
  })

  it('maps invalid_file', async () => {
    const w = await uploadFailing(new ApiError(422, 'invalid_file', 'x'))
    expect(w.get('[role="alert"]').text()).toBe('Please choose a .csv file under 10 MB.')
  })

  it('maps import_in_progress', async () => {
    const w = await uploadFailing(new ApiError(409, 'import_in_progress', 'x'))
    expect(w.get('[role="alert"]').text()).toBe('An import is already running.')
  })

  it('links to library and dashboard once completed', async () => {
    vi.mocked(importsApi.list).mockResolvedValue([])
    const wrapper = mount(OnboardingView, { global: { stubs: { RouterLink: RouterLinkStub } } })
    await flushPromises()
    useImportsStore().current = { ...baseImport, status: 'completed' }
    await flushPromises()
    expect(wrapper.text()).toContain('Done')
    expect(wrapper.findAllComponents(RouterLinkStub).map((l) => l.props('to'))).toEqual([
      '/library',
      '/',
    ])
  })
})
