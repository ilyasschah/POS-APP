// FILE: Products.Api.Queries\UserQuery\GetUserByIdQuery.cs

using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.UserQuery;

public class GetUserByIdQuery : IRequest<UserDto?>
{
    public int Id { get; set; }
    public int CompanyId { get; set; }

    public class GetUserByIdQueryHandler : IRequestHandler<GetUserByIdQuery, UserDto?>
    {
        private readonly UserRepository _repository;

        public GetUserByIdQueryHandler(UserRepository repository)
        {
            _repository = repository;
        }

        public async Task<UserDto?> Handle(GetUserByIdQuery request, CancellationToken cancellationToken)
        {
            var entity = await _repository.GetByIdAsync(request.Id, request.CompanyId);
            return entity == null ? null : MapperUser.MapToUserDto(entity);
        }
    }
}
