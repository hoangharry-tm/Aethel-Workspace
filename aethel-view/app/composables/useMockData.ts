export type Role = 'ADMIN' | 'RECEPTION' | 'USER'

export type UrgencyLevel = 'IMMEDIATE' | 'PRIORITY' | 'ROUTINE'

export type DocumentStatus =
  | 'PENDING_ASSIGNMENT'
  | 'UNDER_REVIEW'
  | 'IN_TRANSIT'
  | 'ATTEMPTED_DELIVERY'
  | 'DELIVERED'
  | 'ESCALATED'
  | 'DISPATCHED'

export type DeliveryMode = 'POST' | 'COURIER' | 'HAND_DELIVERY' | 'EMAIL'

export interface MockUser {
  id: string
  name: string
  email: string
  role: Role
  department: string
  avatar: string
  status: 'active' | 'inactive'
}

export interface MockDocument {
  id: string
  trackingNumber: string
  subject: string
  senderName: string
  senderOrg: string
  documentType: string
  urgency: UrgencyLevel
  status: DocumentStatus
  department: string
  recipientId: string
  deliveryMode: DeliveryMode
  dateReceived: string
  updatedAt: string
  attachments: string[]
  routingChain: string[]
  isInbound: boolean
}

export interface MockNotification {
  id: string
  documentId: string
  trackingNumber: string
  eventType: string
  subjectLine: string
  time: string
  read: boolean
}

export interface MockRoutingRule {
  id: string
  priority: number
  documentType: string
  senderOrg?: string
  urgency?: UrgencyLevel
  destination: string
  stops: string[]
  isActive: boolean
}

const mockUsers: MockUser[] = [
  {
    id: 'u1',
    name: 'Alice Thornton',
    email: 'alice.thornton@aethel.org',
    role: 'ADMIN',
    department: 'Administration',
    avatar: 'https://api.dicebear.com/9.x/initials/svg?seed=AT&backgroundColor=4f46e5&fontColor=ffffff',
    status: 'active',
  },
  {
    id: 'u2',
    name: 'Marcus Webb',
    email: 'marcus.webb@aethel.org',
    role: 'RECEPTION',
    department: 'Reception',
    avatar: 'https://api.dicebear.com/9.x/initials/svg?seed=MW&backgroundColor=0ea5e9&fontColor=ffffff',
    status: 'active',
  },
  {
    id: 'u3',
    name: 'Priya Sharma',
    email: 'priya.sharma@aethel.org',
    role: 'USER',
    department: 'Finance',
    avatar: 'https://api.dicebear.com/9.x/initials/svg?seed=PS&backgroundColor=10b981&fontColor=ffffff',
    status: 'active',
  },
  {
    id: 'u4',
    name: 'Daniel Okafor',
    email: 'daniel.okafor@aethel.org',
    role: 'USER',
    department: 'Legal',
    avatar: 'https://api.dicebear.com/9.x/initials/svg?seed=DO&backgroundColor=f59e0b&fontColor=ffffff',
    status: 'active',
  },
  {
    id: 'u5',
    name: 'Sophie Laurent',
    email: 'sophie.laurent@aethel.org',
    role: 'USER',
    department: 'HR',
    avatar: 'https://api.dicebear.com/9.x/initials/svg?seed=SL&backgroundColor=ec4899&fontColor=ffffff',
    status: 'active',
  },
  {
    id: 'u6',
    name: 'James Okonkwo',
    email: 'james.okonkwo@aethel.org',
    role: 'RECEPTION',
    department: 'Reception',
    avatar: 'https://api.dicebear.com/9.x/initials/svg?seed=JO&backgroundColor=8b5cf6&fontColor=ffffff',
    status: 'active',
  },
  {
    id: 'u7',
    name: 'Mei-Ling Chen',
    email: 'meiling.chen@aethel.org',
    role: 'USER',
    department: 'Operations',
    avatar: 'https://api.dicebear.com/9.x/initials/svg?seed=MC&backgroundColor=06b6d4&fontColor=ffffff',
    status: 'inactive',
  },
  {
    id: 'u8',
    name: 'Robert Haines',
    email: 'robert.haines@aethel.org',
    role: 'USER',
    department: 'Procurement',
    avatar: 'https://api.dicebear.com/9.x/initials/svg?seed=RH&backgroundColor=64748b&fontColor=ffffff',
    status: 'active',
  },
]

const mockDocuments: MockDocument[] = [
  {
    id: 'doc-001',
    trackingNumber: 'AWK-2025-0001',
    subject: 'Q4 Audit Report — Finance Department',
    senderName: 'Ernst & Young LLP',
    senderOrg: 'Ernst & Young',
    documentType: 'Audit Report',
    urgency: 'IMMEDIATE',
    status: 'PENDING_ASSIGNMENT',
    department: 'Finance',
    recipientId: 'u3',
    deliveryMode: 'COURIER',
    dateReceived: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
    attachments: ['audit-report-q4-2025.pdf'],
    routingChain: ['Reception', 'Finance'],
    isInbound: true,
  },
  {
    id: 'doc-002',
    trackingNumber: 'AWK-2025-0002',
    subject: 'Employment Contract — New Hire Package',
    senderName: 'Ministry of Labour',
    senderOrg: 'Ministry of Labour',
    documentType: 'Legal Contract',
    urgency: 'PRIORITY',
    status: 'IN_TRANSIT',
    department: 'HR',
    recipientId: 'u5',
    deliveryMode: 'POST',
    dateReceived: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 60).toISOString(),
    attachments: ['employment-contract-2025.pdf'],
    routingChain: ['Reception', 'HR'],
    isInbound: true,
  },
  {
    id: 'doc-003',
    trackingNumber: 'AWK-2025-0003',
    subject: 'Vendor Invoice — IT Equipment Procurement',
    senderName: 'Dell Technologies',
    senderOrg: 'Dell Technologies',
    documentType: 'Invoice',
    urgency: 'ROUTINE',
    status: 'DELIVERED',
    department: 'Procurement',
    recipientId: 'u8',
    deliveryMode: 'EMAIL',
    dateReceived: new Date(Date.now() - 1000 * 60 * 60 * 5).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString(),
    attachments: ['invoice-dell-2025-11.pdf'],
    routingChain: ['Reception', 'Procurement'],
    isInbound: true,
  },
  {
    id: 'doc-004',
    trackingNumber: 'AWK-2025-0004',
    subject: 'Regulatory Compliance Notice — Data Protection',
    senderName: 'Data Protection Authority',
    senderOrg: 'DPA',
    documentType: 'Regulatory Notice',
    urgency: 'IMMEDIATE',
    status: 'ESCALATED',
    department: 'Legal',
    recipientId: 'u4',
    deliveryMode: 'HAND_DELIVERY',
    dateReceived: new Date(Date.now() - 1000 * 60 * 60 * 3).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 30).toISOString(),
    attachments: ['dpa-notice-2025.pdf'],
    routingChain: ['Reception', 'Legal', 'Administration'],
    isInbound: true,
  },
  {
    id: 'doc-005',
    trackingNumber: 'AWK-2025-0005',
    subject: 'Annual Budget Proposal — FY2026',
    senderName: 'Board of Directors',
    senderOrg: 'Aethel Board',
    documentType: 'Budget Proposal',
    urgency: 'PRIORITY',
    status: 'UNDER_REVIEW',
    department: 'Finance',
    recipientId: 'u3',
    deliveryMode: 'HAND_DELIVERY',
    dateReceived: new Date(Date.now() - 1000 * 60 * 60 * 8).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 60 * 4).toISOString(),
    attachments: ['budget-proposal-fy2026.pdf'],
    routingChain: ['Reception', 'Administration', 'Finance'],
    isInbound: true,
  },
  {
    id: 'doc-006',
    trackingNumber: 'AWK-2025-0006',
    subject: 'Office Lease Renewal Agreement',
    senderName: 'Meridian Properties Ltd',
    senderOrg: 'Meridian Properties',
    documentType: 'Legal Contract',
    urgency: 'PRIORITY',
    status: 'ATTEMPTED_DELIVERY',
    department: 'Administration',
    recipientId: 'u1',
    deliveryMode: 'COURIER',
    dateReceived: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 60 * 6).toISOString(),
    attachments: ['lease-renewal-2025.pdf'],
    routingChain: ['Reception', 'Administration'],
    isInbound: true,
  },
  {
    id: 'doc-007',
    trackingNumber: 'AWK-2025-0007',
    subject: 'Health & Safety Inspection Certificate',
    senderName: 'National Safety Board',
    senderOrg: 'NSB',
    documentType: 'Certificate',
    urgency: 'ROUTINE',
    status: 'DELIVERED',
    department: 'Operations',
    recipientId: 'u7',
    deliveryMode: 'POST',
    dateReceived: new Date(Date.now() - 1000 * 60 * 60 * 48).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString(),
    attachments: ['safety-cert-2025.pdf'],
    routingChain: ['Reception', 'Operations'],
    isInbound: true,
  },
  {
    id: 'doc-008',
    trackingNumber: 'AWK-2025-0008',
    subject: 'Software License Agreement — Enterprise Suite',
    senderName: 'Microsoft Corporation',
    senderOrg: 'Microsoft',
    documentType: 'License Agreement',
    urgency: 'ROUTINE',
    status: 'IN_TRANSIT',
    department: 'IT',
    recipientId: 'u2',
    deliveryMode: 'EMAIL',
    dateReceived: new Date(Date.now() - 1000 * 60 * 90).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 90).toISOString(),
    attachments: ['ms-enterprise-license-2025.pdf'],
    routingChain: ['Reception', 'IT'],
    isInbound: true,
  },
  {
    id: 'doc-009',
    trackingNumber: 'AWK-2025-0009',
    subject: 'Outgoing: Quarterly Report to Stakeholders',
    senderName: 'Alice Thornton',
    senderOrg: 'Aethel Workspace',
    documentType: 'Report',
    urgency: 'PRIORITY',
    status: 'DISPATCHED',
    department: 'Administration',
    recipientId: 'u1',
    deliveryMode: 'COURIER',
    dateReceived: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 30).toISOString(),
    attachments: ['quarterly-report-q4-2025.pdf'],
    routingChain: ['Administration', 'Reception'],
    isInbound: false,
  },
  {
    id: 'doc-010',
    trackingNumber: 'AWK-2025-0010',
    subject: 'Outgoing: Partnership MOU — TechBridge Alliance',
    senderName: 'Robert Haines',
    senderOrg: 'Aethel Workspace',
    documentType: 'MOU',
    urgency: 'IMMEDIATE',
    status: 'PENDING_ASSIGNMENT',
    department: 'Procurement',
    recipientId: 'u8',
    deliveryMode: 'HAND_DELIVERY',
    dateReceived: new Date(Date.now() - 1000 * 60 * 20).toISOString(),
    updatedAt: new Date(Date.now() - 1000 * 60 * 20).toISOString(),
    attachments: ['mou-techbridge-2025.pdf'],
    routingChain: ['Procurement', 'Reception'],
    isInbound: false,
  },
]

const mockNotifications: MockNotification[] = [
  {
    id: 'n1',
    documentId: 'doc-004',
    trackingNumber: 'AWK-2025-0004',
    eventType: 'ESCALATED',
    subjectLine: 'Regulatory Compliance Notice — Data Protection has been escalated',
    time: new Date(Date.now() - 1000 * 60 * 30).toISOString(),
    read: false,
  },
  {
    id: 'n2',
    documentId: 'doc-001',
    trackingNumber: 'AWK-2025-0001',
    eventType: 'PENDING_ASSIGNMENT',
    subjectLine: 'New inbound document awaiting assignment: Q4 Audit Report',
    time: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
    read: false,
  },
  {
    id: 'n3',
    documentId: 'doc-006',
    trackingNumber: 'AWK-2025-0006',
    eventType: 'ATTEMPTED_DELIVERY',
    subjectLine: 'Delivery attempt failed for Office Lease Renewal Agreement',
    time: new Date(Date.now() - 1000 * 60 * 60 * 6).toISOString(),
    read: false,
  },
  {
    id: 'n4',
    documentId: 'doc-002',
    trackingNumber: 'AWK-2025-0002',
    eventType: 'IN_TRANSIT',
    subjectLine: 'Employment Contract is now in transit to HR department',
    time: new Date(Date.now() - 1000 * 60 * 60).toISOString(),
    read: false,
  },
  {
    id: 'n5',
    documentId: 'doc-003',
    trackingNumber: 'AWK-2025-0003',
    eventType: 'DELIVERED',
    subjectLine: 'Vendor Invoice successfully delivered to Procurement',
    time: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString(),
    read: false,
  },
]

const mockRoutingRules: MockRoutingRule[] = [
  {
    id: 'r1',
    priority: 1,
    documentType: 'Regulatory Notice',
    senderOrg: undefined,
    urgency: 'IMMEDIATE',
    destination: 'Legal',
    stops: ['Reception', 'Legal', 'Administration'],
    isActive: true,
  },
  {
    id: 'r2',
    priority: 2,
    documentType: 'Invoice',
    senderOrg: undefined,
    urgency: undefined,
    destination: 'Finance',
    stops: ['Reception', 'Finance'],
    isActive: true,
  },
  {
    id: 'r3',
    priority: 3,
    documentType: 'Legal Contract',
    senderOrg: undefined,
    urgency: undefined,
    destination: 'Legal',
    stops: ['Reception', 'Legal'],
    isActive: true,
  },
  {
    id: 'r4',
    priority: 4,
    documentType: 'Audit Report',
    senderOrg: 'Ernst & Young',
    urgency: undefined,
    destination: 'Finance',
    stops: ['Reception', 'Finance'],
    isActive: true,
  },
  {
    id: 'r5',
    priority: 5,
    documentType: 'General Correspondence',
    senderOrg: undefined,
    urgency: undefined,
    destination: 'Administration',
    stops: ['Reception', 'Administration'],
    isActive: false,
  },
]

export function useMockData() {
  const currentUser = useState<MockUser>('current-user', () => ({
    id: 'u2',
    name: 'Marcus Webb',
    email: 'marcus.webb@aethel.org',
    role: 'RECEPTION',
    department: 'Reception',
    avatar: 'https://api.dicebear.com/9.x/initials/svg?seed=MW&backgroundColor=0ea5e9&fontColor=ffffff',
    status: 'active',
  }))

  function setRole(role: Role) {
    const roleUserMap: Record<Role, MockUser> = {
      ADMIN: mockUsers[0]!,
      RECEPTION: mockUsers[1]!,
      USER: mockUsers[2]!,
    }
    currentUser.value = { ...roleUserMap[role] }
  }

  return {
    currentUser,
    setRole,
    documents: mockDocuments,
    notifications: mockNotifications,
    routingRules: mockRoutingRules,
    users: mockUsers,
  }
}
