const STORAGE_KEY = 'tasks-v1'

const taskForm = document.getElementById('task-form')
const taskInput = document.getElementById('task-input')
const taskList = document.getElementById('task-list')
const statsEl = document.getElementById('task-stats')
const storageStatus = document.getElementById('storage-status')
const errorEl = document.getElementById('task-error')

let tasks = []

function supportsLocalStorage(){
  try{const k = '__s'; localStorage.setItem(k,k); localStorage.removeItem(k); return true}catch(e){return false}
}

function save(){
  if(supportsLocalStorage()) localStorage.setItem(STORAGE_KEY, JSON.stringify(tasks))
}

function load(){
  if(supportsLocalStorage()){
    const raw = localStorage.getItem(STORAGE_KEY)
    if(raw){
      try{tasks = JSON.parse(raw)}catch(e){tasks = []}
    }
  }
}

function render(){
  taskList.innerHTML = ''
  if(tasks.length === 0){
    const li = document.createElement('li')
    li.className = 'task-item'
    li.innerHTML = '<div class="label"><span class="task-text" style="color:var(--muted)">暂无任务 — 赶快添加一个吧！</span></div>'
    taskList.appendChild(li)
  }

  tasks.forEach(task => {
    const li = document.createElement('li')
    li.className = 'task-item'
    li.setAttribute('data-id', task.id)

    const labelWrap = document.createElement('div')
    labelWrap.className = 'label'

    const checkbox = document.createElement('input')
    checkbox.type = 'checkbox'
    checkbox.checked = !!task.completed
    checkbox.id = `chk-${task.id}`
    checkbox.addEventListener('change', () => toggleComplete(task.id))

    const span = document.createElement('span')
    span.className = 'task-text' + (task.completed ? ' completed' : '')
    span.textContent = task.text
    span.setAttribute('aria-live', 'polite')

    const label = document.createElement('label')
    label.htmlFor = checkbox.id
    label.appendChild(span)

    labelWrap.appendChild(checkbox)
    labelWrap.appendChild(label)

    const actions = document.createElement('div')
    actions.className = 'task-actions'

    const del = document.createElement('button')
    del.className = 'icon-btn delete'
    del.type = 'button'
    del.title = `删除: ${task.text}`
    del.setAttribute('aria-label', `删除 ${task.text}`)
    del.innerHTML = '删除'
    del.addEventListener('click', () => removeTask(task.id))

    actions.appendChild(del)

    li.appendChild(labelWrap)
    li.appendChild(actions)
    taskList.appendChild(li)
  })

  updateStats()
}

function addTask(text){
  const trimmed = (text || '').trim()
  const t = {id: String(Date.now()) + Math.random().toString(36).slice(2,6), text: trimmed, completed: false}
  if(!t.text) return
  tasks.unshift(t)
  save(); render(); announce(`${t.text} 已添加`)
}

function showError(msg){
  if(errorEl){
    errorEl.textContent = msg
  } else {
    // Fallback announce
    announce(msg)
  }
  taskInput.classList.add('input-error')
  taskInput.setAttribute('aria-invalid', 'true')
}

function clearError(){
  if(errorEl) errorEl.textContent = ''
  taskInput.classList.remove('input-error')
  taskInput.removeAttribute('aria-invalid')
}

function validateTaskText(text){
  if(typeof text !== 'string') return null
  // collapse multiple spaces and trim
  const normalized = text.replace(/\s+/g, ' ').trim()
  if(!normalized) return null
  if(normalized.length > 200){
    return null
  }
  return normalized
}

function removeTask(id){
  const idx = tasks.findIndex(t=>t.id===id)
  if(idx>-1){
    const removed = tasks.splice(idx,1)[0]
    save(); render(); announce(`${removed.text} 已删除`)
  }
}

function toggleComplete(id){
  const t = tasks.find(x=>x.id===id)
  if(!t) return
  t.completed = !t.completed
  save(); render(); announce(`${t.text} ${t.completed? '标记为已完成':'标记为未完成'}`)
}

function updateStats(){
  const total = tasks.length
  const done = tasks.filter(t=>t.completed).length
  statsEl.textContent = `共 ${total} 项，已完成 ${done} 项`
}

function announce(msg){
  // Simple screen-reader announcement via stats element
  statsEl.textContent = msg
  setTimeout(updateStats, 500)
}

taskForm.addEventListener('submit', e=>{
  e.preventDefault()
  clearError()
  const validated = validateTaskText(taskInput.value)
  if(!validated){
    // provide specific feedback
    if(!taskInput.value || !taskInput.value.trim()){
      showError('请输入任务内容。')
    } else if(taskInput.value.replace(/\s+/g,' ').trim().length > 200){
      showError('任务长度不能超过 200 个字符。')
    } else {
      showError('任务内容无效。')
    }
    taskInput.focus()
    return
  }
  addTask(validated)
  taskInput.value = ''
  taskInput.focus()
})

// keyboard accessibility: space/enter on focused list item toggles checkbox
taskList.addEventListener('keydown', (e)=>{
  const el = e.target
  if((e.key === 'Enter' || e.key === ' ') && el.closest('.task-item')){
    const li = el.closest('.task-item')
    const id = li.getAttribute('data-id')
    if(id){
      toggleComplete(id)
      e.preventDefault()
    }
  }
})

// Init
if(!supportsLocalStorage()) storageStatus.textContent = '不支持'
load()
render()
