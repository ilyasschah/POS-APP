using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Api.Domain
{
    [Table("Booking")]
    public class Booking
    {
        [Key]
        public int Id { get; private set; }
        public int CompanyId { get; private set; }
        public int? CustomerId { get; private set; }
        public int? UserId { get; private set; }

        [MaxLength(100)]
        public string? ReservationName { get; private set; }

        // Stored as a JSON array column — see AppDbContext ValueConverter
        public List<int> TableIds { get; private set; } = new();

        public int? DocumentId { get; private set; }
        public int? PosOrderId { get; private set; }

        public DateTime StartTime { get; private set; } = DateTime.Now;
        public DateTime EndTime { get; private set; }
        public int GuestCount { get; private set; }
        public int Status { get; private set; }

        [MaxLength(500)]
        public string? Note { get; private set; }

        [ForeignKey(nameof(UserId))]
        public virtual User? AssignedUser { get; private set; }

        public Booking() { }

        private Booking(int companyId, string reservationName, DateTime startTime, DateTime endTime,
            int guestCount, int? customerId, List<int>? tableIds, string? note, int? userId)
        {
            CompanyId = companyId;
            ReservationName = reservationName;
            StartTime = startTime;
            EndTime = endTime;
            GuestCount = guestCount;
            CustomerId = customerId;
            TableIds = tableIds ?? new List<int>();
            Note = note;
            UserId = userId;
            Status = 1;
        }

        public static Booking Create(
            int companyId,
            string reservationName,
            DateTime startTime,
            DateTime endTime,
            int guestCount = 1,
            int? customerId = null,
            List<int>? tableIds = null,
            string? note = null,
            int? userId = null)
        {
            if (companyId <= 0) throw new ArgumentException("Invalid Company ID");
            if (string.IsNullOrWhiteSpace(reservationName)) throw new ArgumentException("Reservation name is required.");
            if (startTime >= endTime) throw new ArgumentException("End time must be after start time.");

            return new Booking(companyId, reservationName, startTime, endTime, guestCount, customerId, tableIds, note, userId);
        }

        public void LinkPosOrder(int posOrderId) => PosOrderId = posOrderId;
        public void UnlinkPosOrder() => PosOrderId = null;

        public void MarkAsArrived() => Status = 2;
        public void MarkAsInService(int? documentId = null)
        {
            Status = 3;
            if (documentId.HasValue) DocumentId = documentId;
        }
        public void MarkAsCompleted() => Status = 4;
        public void MarkAsNoShow() => Status = 5;

        public void UpdateStatus(int status, int? documentId = null)
        {
            Status = status;
            if (documentId.HasValue) DocumentId = documentId;
        }

        public void UpdateResource(int? userId, List<int>? tableIds)
        {
            UserId = userId;
            TableIds = tableIds ?? new List<int>();
        }

        public void Update(string reservationName, DateTime startTime, DateTime endTime,
            int guestCount, int? userId, List<int>? tableIds, string? note, int? customerId = null)
        {
            if (string.IsNullOrWhiteSpace(reservationName)) throw new ArgumentException("Reservation name is required.");
            if (startTime >= endTime) throw new ArgumentException("End time must be after start time.");
            ReservationName = reservationName;
            StartTime = startTime;
            EndTime = endTime;
            GuestCount = guestCount;
            UserId = userId;
            TableIds = tableIds ?? new List<int>();
            Note = note;
            CustomerId = customerId;
        }

        public void Reschedule(DateTime newStartTime, DateTime newEndTime)
        {
            if (newStartTime >= newEndTime) throw new ArgumentException("End time must be after start time.");
            StartTime = newStartTime;
            EndTime = newEndTime;
        }
    }
}
