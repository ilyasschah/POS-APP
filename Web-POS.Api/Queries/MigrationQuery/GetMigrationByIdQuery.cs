using MediatR;
using Api.Repository;
using Api.Helpers;
using Api.Models;

namespace Api.Queries.MigrationQuery
{
    public class GetMigrationByIdQuery : IRequest<MigrationDto?>
    {
        public int Id { get; set; }

        public class GetMigrationByIdQueryHandler : IRequestHandler<GetMigrationByIdQuery, MigrationDto?>
        {
            private readonly MigrationRepository _repository;

            public GetMigrationByIdQueryHandler(MigrationRepository repository)
            {
                _repository = repository;
            }

            public async Task<MigrationDto?> Handle(GetMigrationByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperMigration.MapToMigrationDto(entity);
            }
        }
    }
}
