using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperBooking
    {
        public static BookingDto MapToDto(Booking booking)
        {
            return new BookingDto
            {
                Id = booking.Id,
                CustomerId = booking.CustomerId,
                UserId = booking.UserId,
                ReservationName = booking.ReservationName,
                FloorPlanTableId = booking.FloorPlanTableId,
                DocumentId = booking.DocumentId,
                StartTime = booking.StartTime,
                EndTime = booking.EndTime,
                GuestCount = booking.GuestCount,
                Status = booking.Status,
                Note = booking.Note,
            };
        }
    }
}
