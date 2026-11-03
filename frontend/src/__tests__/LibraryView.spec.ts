import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, RouterLinkStub } from '@vue/test-utils'
import { createPinia, setActivePinia } from 'pinia'
import { createMemoryHistory, createRouter } from 'vue-router'
import * as booksApi from '@/api/books'
import LibraryView from '@/views/LibraryView.vue'
import { userBook } from './fixtures'

vi.mock('@/api/books')

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/library', component: LibraryView }],
  })
}

async function mountAt(url: string) {
  const router = makeRouter()
  await router.push(url)
  const wrapper = mount(LibraryView, {
    global: { plugins: [router], stubs: { RouterLink: RouterLinkStub } },
  })
  await flushPromises()
  return { router, wrapper }
}

describe('LibraryView', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    setActivePinia(createPinia())
  })

  it('reads filters from the URL on mount', async () => {
    vi.mocked(booksApi.list).mockResolvedValue({
      data: [userBook(1)],
      meta: { page: 2, per_page: 25, total: 60, total_pages: 3 },
    })
    const { wrapper } = await mountAt('/library?shelf=read&q=dune&sort=title&page=2')
    expect(booksApi.list).toHaveBeenCalledWith(
      expect.objectContaining({ shelf: 'read', q: 'dune', sort: 'title', page: 2 }),
    )
    expect((wrapper.get('select[name="shelf"]').element as HTMLSelectElement).value).toBe('read')
    expect(wrapper.text()).toContain('Book 1')
  })

  it('writes filter and page changes back to the URL', async () => {
    vi.mocked(booksApi.list).mockResolvedValue({
      data: [userBook(1)],
      meta: { page: 1, per_page: 25, total: 60, total_pages: 3 },
    })
    const { router, wrapper } = await mountAt('/library')
    await wrapper.get('select[name="shelf"]').setValue('to-read')
    await flushPromises()
    expect(router.currentRoute.value.query).toEqual({ shelf: 'to-read' })
    await wrapper.findAll('nav[aria-label="Pagination"] button')[1]!.trigger('click')
    await flushPromises()
    expect(router.currentRoute.value.query).toEqual({ shelf: 'to-read', page: '2' })
    await wrapper.get('select[name="sort"]').setValue('title')
    await flushPromises()
    expect(router.currentRoute.value.query).toEqual({ shelf: 'to-read', sort: 'title' })
  })

  it('shows the empty state linking to onboarding', async () => {
    vi.mocked(booksApi.list).mockResolvedValue({
      data: [],
      meta: { page: 1, per_page: 25, total: 0, total_pages: 0 },
    })
    const { wrapper } = await mountAt('/library')
    expect(wrapper.text()).toContain('No books yet')
    expect(wrapper.getComponent(RouterLinkStub).props('to')).toBe('/onboarding')
  })

  it('shows an error state', async () => {
    vi.mocked(booksApi.list).mockRejectedValue(new Error('x'))
    const { wrapper } = await mountAt('/library')
    expect(wrapper.get('[role="alert"]').text()).toContain("Couldn't load")
  })
})
