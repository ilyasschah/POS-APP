namespace Api.Models
{
    public class BookingDto
    {
        public int Id { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public required string ReservationName { get; set; }
        public List<int> TableIds { get; set; } = new();
        public int? DocumentId { get; set; }
        public int? PosOrderId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public int GuestCount { get; set; }
        public int Status { get; set; }
        public string? Note { get; set; }
    }

    public class CreateBookingRequest
    {
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public required string ReservationName { get; set; }
        public List<int> TableIds { get; set; } = new();
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public int GuestCount { get; set; }
        public string? Note { get; set; }
    }

    public class UpdateBookingStatusRequest
    {
        public int BookingId { get; set; }
        public int Status { get; set; }
        public int? DocumentId { get; set; }
    }

    public class UpdateBookingResourceRequest
    {
        public int BookingId { get; set; }
        public int? UserId { get; set; }
        public List<int> TableIds { get; set; } = new();
    }

    public class UpdateBookingRequest
    {
        public int BookingId { get; set; }
        public required string ReservationName { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public int GuestCount { get; set; }
        public int? CustomerId { get; set; }
        public int? UserId { get; set; }
        public List<int> TableIds { get; set; } = new();
        public string? Note { get; set; }
    }
}
