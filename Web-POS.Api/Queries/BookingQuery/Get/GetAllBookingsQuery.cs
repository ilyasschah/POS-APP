using FluentValidation;
using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.BookingQuery.Get
{
    public class GetAllBookingsQuery : IRequest<List<BookingDto>>
    {
        public int CompanyId { get; set; }

        public class GetAllBookingsQueryHandler : IRequestHandler<GetAllBookingsQuery, List<BookingDto>>
        {
            private readonly BookingRepository _repository;

            public GetAllBookingsQueryHandler(BookingRepository repository)
            {
                _repository = repository;
            }

            public async Task<List<BookingDto>> Handle(GetAllBookingsQuery request, CancellationToken cancellationToken)
            {
                var bookings = await _repository.GetAllAsync(request.CompanyId);
                return bookings.Select(MapperBooking.MapToDto).ToList();
            }
        }
    }

    public class GetAllBookingsQueryValidator : AbstractValidator<GetAllBookingsQuery>
    {
        public GetAllBookingsQueryValidator()
        {
            RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
        }
    }
}
