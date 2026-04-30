using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.BookingQuery.Get
{
    public class GetBookingByIdQuery : IRequest<BookingDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class GetBookingByIdQueryHandler : IRequestHandler<GetBookingByIdQuery, BookingDto?>
        {
            private readonly BookingRepository _repository;

            public GetBookingByIdQueryHandler(BookingRepository repository)
            {
                _repository = repository;
            }

            public async Task<BookingDto?> Handle(GetBookingByIdQuery request, CancellationToken cancellationToken)
            {
                var booking = await _repository.GetByIdAsync(request.Id, request.CompanyId);
                return booking == null ? null : MapperBooking.MapToDto(booking);
            }
        }
    }

    public class GetBookingByIdQueryValidator : AbstractValidator<GetBookingByIdQuery>
    {
        public GetBookingByIdQueryValidator()
        {
            RuleFor(x => x.Id).GreaterThan(0).WithMessage("Booking ID must be valid.");
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
